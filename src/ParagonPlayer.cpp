/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>,
 * released under GNU AGPL v3 license:
 * https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include <sstream>
#include <cmath>
#include "SpellAuraEffects.h"

enum Spellids
{
    AURA_PARAGONLEVEL = 100000,
    AURA_STRENGTH = 7507,
    AURA_INTELLECT = 100002,
    AURA_AGILITY = 100003,
    AURA_SPIRIT = 100004,
    AURA_STAMINA = 100005,
    AURA_ARMOR_PENETRATION = 100006,
    AURA_SPELL_PENETRATION = 100007,
    AURA_SPELL_POWER = 100008,
};

const uint8 paragonPointsPerLevel = 5;

/// Helper: Applies (or updates) a bonus aura with the given spellId so that its effect amount equals bonusValue.
/// This avoids using SetAuraStack (limited to 255) by directly modifying the effect amount.
void ApplyBonusAura(Player* player, uint32 spellId, uint32 bonusValue)
{
    // Try to find an existing aura.
    if (Aura* aura = player->GetAura(spellId))
    {
        aura->GetEffect(0)->ChangeAmount(bonusValue);
    }
    else if (Aura* aura = player->AddAura(spellId, player))
    {
        aura->GetEffect(0)->ChangeAmount(bonusValue);
    }
}

/// Refresh all paragon bonus auras on the player.
void RefreshParagonStats(Player* player,
    uint32 pstrength, uint32 pintellect, uint32 pagility, uint32 pspirit, uint32 pstamina,
    uint32 parmorpen, uint32 pspellpen, uint32 pspellpower)
{
    ApplyBonusAura(player, AURA_STRENGTH, pstrength);
    ApplyBonusAura(player, AURA_INTELLECT, pintellect);
    ApplyBonusAura(player, AURA_AGILITY, pagility);
    ApplyBonusAura(player, AURA_SPIRIT, pspirit);
    ApplyBonusAura(player, AURA_STAMINA, pstamina);
    ApplyBonusAura(player, AURA_ARMOR_PENETRATION, parmorpen);
    ApplyBonusAura(player, AURA_SPELL_PENETRATION, pspellpen);
    ApplyBonusAura(player, AURA_SPELL_POWER, pspellpower);

    // Optionally, restore health/mana when not in dungeon/raid.
    if (!player->GetMap()->IsDungeon() && !player->GetMap()->IsRaid())
    {
        player->SetHealth(player->GetMaxHealth());
        if (player->getPowerType() == POWER_MANA)
            player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
    }
}

// Add player scripts
class ParagonPlayer : public PlayerScript
{
public:
    ParagonPlayer() : PlayerScript("ParagonPlayer") {}

    void OnLogin(Player* player) override
    {
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        uint32 accountID = player->GetSession()->GetAccountId();
        QueryResult qr = CharacterDatabase.Query("SELECT level FROM character_paragon WHERE accountID = '{}'", accountID);
        if (qr)
        {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            // Set the paragon level aura (its stack value is used only for display)
            player->AddAura(AURA_PARAGONLEVEL, player);
            player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);

            // Load paragon points (now including 3 new stats)
            // Expecting columns: characterID, pstrength, pintellect, pagility, pspirit, pstamina, parmorpen, pspellpen, pspellpower
            QueryResult qrtwo = CharacterDatabase.Query("SELECT * FROM character_paragon_points WHERE characterID = '{}'", characterID);
            if (qrtwo)
            {
                uint32 pstrength = (*qrtwo)[1].Get<uint32>();
                uint32 pintellect = (*qrtwo)[2].Get<uint32>();
                uint32 pagility = (*qrtwo)[3].Get<uint32>();
                uint32 pspirit = (*qrtwo)[4].Get<uint32>();
                uint32 pstamina = (*qrtwo)[5].Get<uint32>();
                uint32 parmorpen = (*qrtwo)[6].Get<uint32>();
                uint32 pspellpen = (*qrtwo)[7].Get<uint32>();
                uint32 pspellpower = (*qrtwo)[8].Get<uint32>();

                // Check for corrupted points.
                uint32 unspentPoints = player->GetItemCount(920920);
                if ((pstrength + pintellect + pagility + pspirit + pstamina +
                    parmorpen + pspellpen + pspellpower + unspentPoints) != paragonLevel * paragonPointsPerLevel)
                {
                    CharacterDatabase.Execute("UPDATE character_paragon_points SET pstrength = 0, pintellect = 0, pagility = 0, pspirit = 0, pstamina = 0, parmorpen = 0, pspellpen = 0, pspellpower = 0 WHERE characterID = '{}'", characterID);
                    ChatHandler(player->GetSession()).SendSysMessage("There was an error loading your Abyssal Mastery points, please reallocate them!");
                    player->DestroyItemCount(920920, player->GetItemCount(920920), true);
                    player->AddItem(920920, paragonLevel * paragonPointsPerLevel);
                }
                RefreshParagonStats(player, pstrength, pintellect, pagility, pspirit, pstamina, parmorpen, pspellpen, pspellpower);
            }
            else
            {
                // Account found but new character – insert new row with zeroed values for all 8 stats.
                CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina, parmorpen, pspellpen, pspellpower) VALUES ('{}', 0, 0, 0, 0, 0, 0, 0, 0)", characterID);
                uint32 unspentPoints = player->GetItemCount(920920);
                player->AddItem(920920, paragonLevel * paragonPointsPerLevel - unspentPoints);
                ChatHandler(player->GetSession()).SendSysMessage("You can allocate your Abyssal points!");
            }
        }
        else
        {
            // Unlock paragon for a new account.
            CharacterDatabase.Query("INSERT INTO character_paragon (accountID, level, xp) VALUES ('{}', 1, 100)", accountID);
            CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina, parmorpen, pspellpen, pspellpower) VALUES ('{}', 0, 0, 0, 0, 0, 0, 0, 0)", characterID);
        }
    }

    void OnMapChanged(Player* player) override
    {
        if (!player->HasAura(AURA_PARAGONLEVEL))
        {
            uint32 accountID = player->GetSession()->GetAccountId();
            ObjectGuid pGUID = player->GetGUID();
            uint32 characterID = pGUID.GetRawValue();
            QueryResult qr = CharacterDatabase.Query("SELECT level FROM character_paragon WHERE accountID = '{}'", accountID);
            if (qr)
            {
                uint32 paragonLevel = (*qr)[0].Get<uint32>();
                if (paragonLevel > 0)
                {
                    player->AddAura(AURA_PARAGONLEVEL, player);
                    player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
                    QueryResult qrtwo = CharacterDatabase.Query("SELECT * FROM character_paragon_points WHERE characterID = '{}'", characterID);
                    if (qrtwo)
                    {
                        uint32 pstrength = (*qrtwo)[1].Get<uint32>();
                        uint32 pintellect = (*qrtwo)[2].Get<uint32>();
                        uint32 pagility = (*qrtwo)[3].Get<uint32>();
                        uint32 pspirit = (*qrtwo)[4].Get<uint32>();
                        uint32 pstamina = (*qrtwo)[5].Get<uint32>();
                        uint32 parmorpen = (*qrtwo)[6].Get<uint32>();
                        uint32 pspellpen = (*qrtwo)[7].Get<uint32>();
                        uint32 pspellpower = (*qrtwo)[8].Get<uint32>();
                        RefreshParagonStats(player, pstrength, pintellect, pagility, pspirit, pstamina, parmorpen, pspellpen, pspellpower);
                    }
                }
            }
        }
    }

    void OnPlayerResurrect(Player* player, float /*restore_percent*/, bool /*applySickness*/) override
    {
        uint32 accountID = player->GetSession()->GetAccountId();
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        QueryResult qr = CharacterDatabase.Query("SELECT level FROM character_paragon WHERE accountID = '{}'", accountID);
        if (qr)
        {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            if (paragonLevel > 0)
            {
                player->AddAura(AURA_PARAGONLEVEL, player);
                player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
                QueryResult qrtwo = CharacterDatabase.Query("SELECT * FROM character_paragon_points WHERE characterID = '{}'", characterID);
                if (qrtwo)
                {
                    uint32 pstrength = (*qrtwo)[1].Get<uint32>();
                    uint32 pintellect = (*qrtwo)[2].Get<uint32>();
                    uint32 pagility = (*qrtwo)[3].Get<uint32>();
                    uint32 pspirit = (*qrtwo)[4].Get<uint32>();
                    uint32 pstamina = (*qrtwo)[5].Get<uint32>();
                    uint32 parmorpen = (*qrtwo)[6].Get<uint32>();
                    uint32 pspellpen = (*qrtwo)[7].Get<uint32>();
                    uint32 pspellpower = (*qrtwo)[8].Get<uint32>();
                    RefreshParagonStats(player, pstrength, pintellect, pagility, pspirit, pstamina, parmorpen, pspellpen, pspellpower);
                }
            }
        }
    }

    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (quest->IsDailyOrWeekly() && quest->GetQuestLevel() == 80)
            IncreaseParagonXP(player, 3);
    }

    void OnCreatureKill(Player* killer, Creature* killed) override
    {
        CalculateXPGain(killer, killed);
    }

    void OnCreatureKilledByPet(Player* killer, Creature* killed) override
    {
        CalculateXPGain(killer, killed);
    }

    void CalculateXPGain(Player* killer, Creature* killed)
    {
        if (killer->HasAura(AURA_PARAGONLEVEL))
        {
            uint32 xpAmount = 0;
            if ((killed->GetLevel() - killer->GetLevel() >= 0) && !killed->IsPet())
            {
                bool isElite = killed->isElite();
                bool isDungeon = killed->GetMap()->IsNonRaidDungeon();
                bool isRaid = killed->GetMap()->IsRaid();
                bool isWorldBoss = killed->isWorldBoss();
                bool isHeroic = killed->GetMap()->IsHeroic();
                bool isDungeonBoss = killed->IsDungeonBoss();

                if (isElite && (!isDungeon && !isRaid) && !isWorldBoss)
                    xpAmount = 1;
                else if (isElite && (!isDungeon && !isRaid) && isWorldBoss)
                    xpAmount = 20;
                else if (isElite && isDungeon && !isHeroic && !isDungeonBoss)
                    xpAmount = 1;
                else if (isElite && isDungeon && !isHeroic && isDungeonBoss)
                    xpAmount = 3;
                else if (isElite && isDungeon && isHeroic && !isDungeonBoss)
                    xpAmount = 2;
                else if (isElite && isDungeon && isHeroic && isDungeonBoss)
                    xpAmount = 5;
                else if (isElite && isRaid && isWorldBoss)
                    xpAmount = 10;

                if (xpAmount > 0)
                {
                    if (Group* group = killer->GetGroup())
                    {
                        Group::MemberSlotList const& groupMembers = group->GetMemberSlots();
                        for (auto const& memberSlot : groupMembers)
                        {
                            if (Player* player = ObjectAccessor::GetPlayer(killer->GetMap(), memberSlot.guid))
                                IncreaseParagonXP(player, xpAmount);
                        }
                    }
                    else
                    {
                        IncreaseParagonXP(killer, xpAmount);
                    }
                }
            }
        }
    }

    void IncreaseParagonXP(Player* player, uint32 value)
    {
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        uint32 accountID = player->GetSession()->GetAccountId();
        QueryResult qr = CharacterDatabase.Query("SELECT level, xp FROM character_paragon WHERE accountID = '{}'", accountID);
        if (qr)
        {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            uint32 paragonXP = (*qr)[1].Get<uint32>();

            int32 diff = (paragonXP - value);
            if (diff <= 0)
            {
                uint32 xpLeft = value - paragonXP;
                int32 newXP = (100 * pow(1.1, paragonLevel - 1)) - xpLeft;
                if (newXP < 0)
                {
                    std::ostringstream ss;
                    ss << "There was an error calculating abyssal level, please report this to discord! xp left: " << xpLeft
                        << ", paragon level: " << paragonLevel << ", value: " << value << ", newxp: " << newXP;
                    ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                    newXP = 100;
                }
                CharacterDatabase.Query("UPDATE character_paragon SET xp = '{}', level = level + 1 WHERE accountID = '{}'", newXP, accountID);
                player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel + 1);
                std::ostringstream ss;
                ss << "Congratulations " << player->GetName() << "! You increased your Abyssal level to " << paragonLevel + 1 << ".";
                ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                player->AddItem(920920, paragonPointsPerLevel);
            }
            else
            {
                CharacterDatabase.Query("UPDATE character_paragon SET xp = xp - '{}' WHERE accountID = '{}'", value, accountID);
                if (value > 0)
                {
                    std::ostringstream ss;
                    ss << "Increasing Abyssal XP by " << value << ". " << paragonXP - value << " needed to level up.";
                    ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                }
            }
        }
    }
};

// Add all scripts in one
void AddParagonPlayerScripts()
{
    new ParagonPlayer();
}
