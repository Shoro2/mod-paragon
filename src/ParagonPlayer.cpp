/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "ElunaIncludes.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ParagonUtils.h"
#include "lua.h"
#include "lauxlib.h"
#include "LuaEngine.h"



bool debug = true;

enum Spellids
{
    AURA_PARAGONLEVEL = 100000,
    AURA_STRENGTH = 7507,
    AURA_INTELLECT = 100002,
    AURA_AGILITY = 100003,
    AURA_SPIRIT = 100004,
    AURA_STAMINA = 100005,
    AURA_HASTE = 100016,
    AURA_ARMORPEN = 100017,
    AURA_SPELLPOWER = 100018,
    AURA_CRIT = 100019,
    AURA_MSPEED = 100020,
    AURA_MREG = 100021,
    AURA_HIT = 100022,
    AURA_BLOCK = 100023,
    AURA_EXPERTISE = 100024,
    AURA_PARRY = 100025,
    AURA_DODGE = 100026,

    
    
};

void RefreshParagonAura(Player* player, uint8 pstrength, uint8 pintellect, uint8 pagility, uint8 pspirit, uint8 pstamina, uint8 phaste, uint8 parmpen, uint8 pspellpower, uint8 pcrit, uint8 pmspeed, uint8 pmreg, uint8 phit, uint8 pblock, uint8 pexpertise, uint8 pdodge, uint8 pparry) {

    player->RemoveAura(AURA_STRENGTH);
    player->RemoveAura(AURA_INTELLECT);
    player->RemoveAura(AURA_AGILITY);
    player->RemoveAura(AURA_SPIRIT);
    player->RemoveAura(AURA_STAMINA);
    player->RemoveAura(AURA_HASTE);
    player->RemoveAura(AURA_ARMORPEN);
    player->RemoveAura(AURA_SPELLPOWER);
    player->RemoveAura(AURA_CRIT);
    player->RemoveAura(AURA_MSPEED);
    player->RemoveAura(AURA_MREG);
    player->RemoveAura(AURA_HIT);
    player->RemoveAura(AURA_BLOCK);
    player->RemoveAura(AURA_EXPERTISE);
    player->RemoveAura(AURA_PARRY);
    player->RemoveAura(AURA_DODGE);




    if (pstrength > 0) player->AddAura(AURA_STRENGTH, player);
    if (pstrength > 0) player->SetAuraStack(AURA_STRENGTH, player, pstrength);
    if (pintellect > 0) player->AddAura(AURA_INTELLECT, player);
    if (pintellect > 0) player->SetAuraStack(AURA_INTELLECT, player, pintellect);
    if (pagility > 0) player->AddAura(AURA_AGILITY, player);
    if (pagility > 0) player->SetAuraStack(AURA_AGILITY, player, pagility);
    if (pspirit > 0) player->AddAura(AURA_SPIRIT, player);
    if (pspirit > 0) player->SetAuraStack(AURA_SPIRIT, player, pspirit);
    if (pstamina > 0) player->AddAura(AURA_STAMINA, player);
    if (pstamina > 0) player->SetAuraStack(AURA_STAMINA, player, pstamina);
    if (phaste > 0) player->AddAura(AURA_HASTE, player);
    if (phaste > 0) player->SetAuraStack(AURA_HASTE, player, phaste);
    if (parmpen > 0) player->AddAura(AURA_ARMORPEN, player);
    if (parmpen > 0) player->SetAuraStack(AURA_ARMORPEN, player, parmpen);
    if (pspellpower > 0) player->AddAura(AURA_SPELLPOWER, player);
    if (pspellpower > 0) player->SetAuraStack(AURA_SPELLPOWER, player, pspellpower);
    if (pcrit > 0) player->AddAura(AURA_CRIT, player);
    if (pcrit > 0) player->SetAuraStack(AURA_CRIT, player, pcrit);
    if (pmspeed > 0) player->AddAura(AURA_MSPEED, player);
    if (pmspeed > 0) player->SetAuraStack(AURA_MSPEED, player, pmspeed);
    if (pmreg > 0) player->AddAura(AURA_MREG, player);
    if (pmreg > 0) player->SetAuraStack(AURA_MREG, player, pmreg);
    if (phit > 0) player->AddAura(AURA_HIT, player);
    if (phit > 0) player->SetAuraStack(AURA_HIT, player, phit);
    if (pblock > 0) player->AddAura(AURA_BLOCK, player);
    if (pblock > 0) player->SetAuraStack(AURA_BLOCK, player, pblock);
    if (pexpertise > 0) player->AddAura(AURA_EXPERTISE, player);
    if (pexpertise > 0) player->SetAuraStack(AURA_EXPERTISE, player, pexpertise);
    if (pparry > 0) player->AddAura(AURA_PARRY, player);
    if (pparry > 0) player->SetAuraStack(AURA_PARRY, player, pparry);
    if (pdodge > 0) player->AddAura(AURA_DODGE, player);
    if (pdodge > 0) player->SetAuraStack(AURA_DODGE, player, pdodge);



    if (!player->GetMap()->IsDungeon() && !player->GetMap()->IsRaid()) {
        player->SetHealth(player->GetMaxHealth());
        if (player->getPowerType() == POWER_MANA) {
            player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
        }
    }
}



void ApplyParagonStatEffects(Player* player)
{
    QueryResult qrtwo = CharacterDatabase.Query("SELECT * FROM character_paragon_points WHERE characterID = '{}'", player->GetGUID().GetRawValue());
    if (!qrtwo)
        return;

    uint32 pstrength = (*qrtwo)[1].Get<uint32>();
    uint32 pintellect = (*qrtwo)[2].Get<uint32>();
    uint32 pagility = (*qrtwo)[3].Get<uint32>();
    uint32 pspirit = (*qrtwo)[4].Get<uint32>();
    uint32 pstamina = (*qrtwo)[5].Get<uint32>();
    uint32 phaste = (*qrtwo)[6].Get<uint32>();
    uint32 parmpen = (*qrtwo)[7].Get<uint32>();
    uint32 pspellpower = (*qrtwo)[8].Get<uint32>();
    uint32 pcrit = (*qrtwo)[9].Get<uint32>();
    uint32 pmspeed = (*qrtwo)[10].Get<uint32>();
    uint32 pmreg = (*qrtwo)[11].Get<uint32>();
    uint32 phit = (*qrtwo)[12].Get<uint32>();
    uint32 pblock = (*qrtwo)[13].Get<uint32>();
    uint32 pexpertise = (*qrtwo)[14].Get<uint32>();
    uint32 pparry = (*qrtwo)[15].Get<uint32>();
    uint32 pdodge = (*qrtwo)[16].Get<uint32>();

    uint32 unspentPoints = player->GetItemCount(920920);
    ObjectGuid pGUID = player->GetGUID();
    uint32 characterID = pGUID.GetRawValue();
    uint8 paragonLevel = player->GetAuraCount(AURA_PARAGONLEVEL);
    if ((pstrength + pintellect + pagility + pspirit + pstamina + phaste + parmpen + pspellpower + pcrit + pmspeed + pmreg + phit + pblock + pexpertise + pparry + pdodge + unspentPoints) != paragonLevel * 5) {
        CharacterDatabase.Execute("UPDATE character_paragon_points SET pstrength = 0, pintellect = 0, pagility = 0, pspirit = 0, pstamina = 0, phaste = 0, parmpen = 0, pspellpower = 0,  pcrit = 0, pmspeed = 0, pmreg = 0, phit = 0, pblock = 0, pexpertise = 0, pparry = 0, pdodge = 0 WHERE characterID = '{}'", characterID);
        ChatHandler(player->GetSession()).SendSysMessage("There was an error loading your Abyssal points, please reallocate them!");
        player->DestroyItemCount(920920, player->GetItemCount(920920), true);
        player->AddItem(920920, paragonLevel * 5);
    }

    RefreshParagonAura(player, pstrength, pintellect, pagility, pspirit, pstamina, phaste, parmpen, pspellpower, pcrit, pmspeed, pmreg, phit, pblock, pexpertise, pdodge, pparry);

    ChatHandler(player->GetSession()).SendSysMessage("Abyssal stats reapplied.");
}

// Add player scripts
class ParagonPlayer : public PlayerScript
{
public:
    ParagonPlayer() : PlayerScript("ParagonPlayer") { }

    void OnLogin(Player* player) override {
        uint32 accountID = player->GetSession()->GetAccountId();
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE accountID = '{}'", accountID);
        if (qr) {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            player->AddAura(AURA_PARAGONLEVEL, player);
            player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
            QueryResult qrtwor = CharacterDatabase.Query("SELECT * FROM character_paragon_points WHERE characterID = '{}'", characterID);
            if(!qrtwor) // has account but fresh char
            {
                CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina, phaste, parmpen, pspellpower, pcrit, pmspeed, pmreg, phit, pblock, pexpertise, pparry, pdodge) VALUES ('{}', 0, 0, 0, 0 ,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)", characterID);
                ApplyParagonStatEffects(player);
            }
            else {
                ApplyParagonStatEffects(player);
            }
        }
        else {
            //unlock paragon
            CharacterDatabase.Query("INSERT INTO character_paragon (accountID, level, xp) VALUES ('{}', 1, 100)", accountID);
            CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina, phaste, parmpen, pspellpower, pcrit, pmspeed, pmreg, phit, pblock, pexpertise, pparry, pdodge) VALUES ('{}', 0, 0, 0, 0 ,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)", characterID);
        }

    }

    void OnMapChanged(Player* player) override
    {
        if (!player->HasAura(AURA_PARAGONLEVEL))
        {
            uint32 accountID = player->GetSession()->GetAccountId();
            QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE accountID = '{}'", accountID);
            if (qr) {
                uint32 paragonLevel = (*qr)[0].Get<uint32>();
                if (paragonLevel > 0) {
                    player->AddAura(AURA_PARAGONLEVEL, player);
                    player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
                    ApplyParagonStatEffects(player);
                }
                
            }
        }
        else {
            ApplyParagonStatEffects(player);
        }
        
    }

    void OnLevelChanged(Player* player, uint8 /*oldlevel*/) override
    {
        if (player->GetLevel() == 80 && !player->HasAura(AURA_PARAGONLEVEL))
        {
            //create entry in character_paragon
            ObjectGuid pGUID = player->GetGUID();
            uint32 characterID = pGUID.GetRawValue();
            uint32 accountID = player->GetSession()->GetAccountId();
            QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE accountID = '{}'", accountID);
            if (!qr) {
                CharacterDatabase.Query("INSERT INTO character_paragon (accountID, level, xp) VALUES ('{}', 1, 100)", accountID);
                CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina, phaste, parmpen, pspellpower, pcrit, pmspeed, pmreg, phit, pblock, pexpertise, pparry, pdodge) VALUES ('{}', 0, 0, 0, 0 ,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)", characterID);
            }
        }
    }

    /*
    void OnPlayerResurrect(Player* player, float /*restore_percent, bool /*applySickness) override
    {
        if (!player->HasAura(AURA_PARAGONLEVEL))
        {
            uint32 accountID = player->GetSession()->GetAccountId();
            QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE accountID = '{}'", accountID);
            if (qr) {
                uint32 paragonLevel = (*qr)[0].Get<uint32>();
                if (paragonLevel > 0) {
                    player->AddAura(AURA_PARAGONLEVEL, player);
                    player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
                    ApplyParagonStatEffects(player);
                }

            }
        }
        else {
            ApplyParagonStatEffects(player);
        }
    }
    */

    void OnPlayerCompleteQuest(Player* player, Quest const* quest_id) override {
        if (quest_id->IsDailyOrWeekly() && quest_id->GetQuestLevel() == 80) {
            IncreaseParagonXP(player, 3);
        }
    }

    void OnCreatureKill(Player* killer, Creature* killed) override
    {
        CalculateXPGain(killer, killed);
       
    }


    void OnCreatureKilledByPet(Player* killer, Creature* killed) override
    {
        CalculateXPGain(killer, killed);
    }

    void CalculateXPGain(Player* killer, Creature* killed) {
        if (killer->HasAura(AURA_PARAGONLEVEL)) {
            //increase xp
            //valid for xp
            uint32 xpAmount = 0;
            if ((killed->GetLevel() - killer->GetLevel() >= 0) && !killed->IsPet()) {
                bool isElite = killed->isElite(), isDungeon = killed->GetMap()->IsNonRaidDungeon(), isRaid = killed->GetMap()->IsRaid(), isWorldBoss = killed->isWorldBoss(), isHeroic = killed->GetMap()->IsHeroic(), isDungeonBoss = killed->IsDungeonBoss();
                //std::ostringstream ss;
                //ss << "isElite: " << isElite << ", isDungeon: " << isDungeon << ", isRaid: " << isRaid <<", isWorldBoss: " << isWorldBoss << ", isHeroic: " << isHeroic << ", isDungeonBoss: " << isDungeonBoss;
                //ChatHandler(killer->GetSession()).SendSysMessage(ss.str().c_str());
                // normal elite: 1
                if (isElite && (!isDungeon && !isRaid) && !isWorldBoss) {
                    xpAmount = 1;
                }

                //world boss: 20
                else if (isElite && (!isDungeon && !isRaid) && isWorldBoss) {
                    xpAmount = 20;
                }
                //dungeon
                //dungeon elite: 1
                else if (isElite && isDungeon && !isHeroic && !isDungeonBoss) {
                    xpAmount = 1;
                }

                //dungeon boss: 3
                else if (isElite && isDungeon && !isHeroic && isDungeonBoss) {
                    xpAmount = 3;
                }

                //heroic dungeon elite: 2
                else if (isElite && isDungeon && isHeroic && !isDungeonBoss) {
                    xpAmount = 2;
                }

                //heroic dungeon boss: 5
                else if (isElite && isDungeon && isHeroic && isDungeonBoss) {
                    xpAmount = 5;
                }

                //raid
                //raid boss: 10
                else if (isElite && isRaid && isWorldBoss) {
                    xpAmount = 10;
                }
                if (xpAmount > 0) {
                    if (Group* myGroup = killer->GetGroup()) {
                        Group::MemberSlotList const& groupMembers = myGroup->GetMemberSlots();

                        for (auto member = groupMembers.begin(); member != groupMembers.end(); ++member)
                        {
                            if (Player* player = ObjectAccessor::GetPlayer(killer->GetMap(), member->guid)) {
                                IncreaseParagonXP(player, xpAmount);
                            }
                        }
                    }
                    else {
                        IncreaseParagonXP(killer, xpAmount);
                    }
                }

                
            }

        }
    }

    // On Quest reward

    

};

void IncreaseParagonXP(Player* player, uint32 value)
{
    uint32 accountID = player->GetSession()->GetAccountId();
    QueryResult qr = CharacterDatabase.Query("Select level, xp FROM character_paragon WHERE accountID = '{}'", accountID);
    if (qr) {
        uint32 paragonLevel = (*qr)[0].Get<uint32>();
        uint32 paragonXP = (*qr)[1].Get<uint32>();

        int32 diff = (paragonXP - value);
        // level = 16
        // paragonXP = 10
        // value = 20
        if (diff <= 0) // level up
        {
            uint32 xpLeft = value - paragonXP; // +10
            uint32 newXP = (100 * pow(1.1, paragonLevel - 1)) - xpLeft; // (100 * (pow(1.1, (1 - 1)))) - 10
            if (newXP < 0) {
                std::ostringstream ss;
                ss << "There was an error calculating abyssal level, please report this to discord! xp left: " << xpLeft << ", paragon level: " << paragonLevel << ", value: " << value << ", newxp: " << newXP;
                ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                newXP = 100;
            }
            QueryResult qr = CharacterDatabase.Query("UPDATE character_paragon SET xp = '{}', level = level + 1 WHERE accountID = '{}'", newXP, accountID);
            player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel + 1);

            std::ostringstream ss;
            ss << "Congratulations " << player->GetName() << "! You increased your Abyssal level to " << paragonLevel + 1 << ".";
            ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
            player->AddItem(920920, 5);
        }
        else {
            //update xp
            QueryResult qr = CharacterDatabase.Query("UPDATE character_paragon SET xp = xp - '{}' WHERE accountID = '{}'", value, accountID);
            if (value > 0) {
                if ((paragonXP - value) % 100 == 0 || value >= 10) {
                    std::ostringstream ss;
                    uint32 xpGain = value;

                    ss << "Increasing Abyssal XP by " << xpGain << ". " << paragonXP - value << " needed to level up.";
                    ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                }
            }
        }
    }
}

// Add all scripts in one
void AddParagonPlayerScripts()
{
    new ParagonPlayer();
}
