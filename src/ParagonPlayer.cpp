/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"

bool debug = true;

enum Spellids
{
    AURA_PARAGONLEVEL = 100000,
    AURA_STRENGTH = 7507,
    AURA_INTELLECT = 100002,
    AURA_AGILITY = 100003,
    AURA_SPIRIT = 100004,
    AURA_STAMINA = 100005,
    
    
};

// Add player scripts
class ParagonPlayer : public PlayerScript
{
public:
    ParagonPlayer() : PlayerScript("ParagonPlayer") { }

    void OnLogin(Player* player) override {
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE characterID = '{}'", characterID);
        if (qr) {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            player->AddAura(AURA_PARAGONLEVEL, player);
            player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
            
            //load paragon points
            // AttributesAuraIds = { 7464, 7471, 7477, 7468, 7474 } -- Strength, Agility, Stamina, Intellect, Spirit
            QueryResult qrtwo = CharacterDatabase.Query("Select * FROM character_paragon_points WHERE characterID = '{}'", characterID);
            if (qrtwo) {
                uint32 pstrength = (*qrtwo)[1].Get<uint32>();
                uint32 pintellect = (*qrtwo)[2].Get<uint32>();
                uint32 pagility = (*qrtwo)[3].Get<uint32>();
                uint32 pspirit = (*qrtwo)[4].Get<uint32>();
                uint32 pstamina = (*qrtwo)[5].Get<uint32>();

                //check for corrupted points
                uint32 unspentPoints = player->GetItemCount(920920);
                
                if ((pstrength + pintellect + pagility + pspirit + pstamina + unspentPoints) != paragonLevel * 5) {
                    CharacterDatabase.Execute("UPDATE character_paragon_points SET pstrength = 0, pintellect = 0, pagility = 0, pspirit = 0, pstamina = 0 WHERE characterID = '{}'", characterID);
                    ChatHandler(player->GetSession()).SendSysMessage("There was an error loading your paragon points, please reallocate them!");
                    player->DestroyItemCount(920920, player->GetItemCount(920920), true);
                    player->AddItem(920920, paragonLevel * 5);
                }

                player->AddAura(AURA_STRENGTH, player);
                player->SetAuraStack(AURA_STRENGTH, player, pstrength);
                player->AddAura(AURA_INTELLECT, player);
                player->SetAuraStack(AURA_INTELLECT, player, pintellect);
                player->AddAura(AURA_AGILITY, player);
                player->SetAuraStack(AURA_AGILITY, player, pagility);
                player->AddAura(AURA_SPIRIT, player);
                player->SetAuraStack(AURA_SPIRIT, player, pspirit);
                player->AddAura(AURA_STAMINA, player);
                player->SetAuraStack(AURA_STAMINA, player, pstamina);

                if (!player->GetMap()->IsDungeon() && !player->GetMap()->IsRaid()) {
                    player->SetHealth(player->GetMaxHealth());
                    if (player->getPowerType() == POWER_MANA) {
                        player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
                    }
                }

                

                
            }
            else {
                //account found but new character
                CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina) VALUES ('{}', 0, 0, 0, 0 ,0)", characterID);
                uint32 unspentPoints = player->GetItemCount(920920);
                player->AddItem(920920, paragonLevel * 5 - unspentPoints);
                ChatHandler(player->GetSession()).SendSysMessage("You can allocate your paragon points!");
            }
        }
        else {
            //unlock paragon
            ObjectGuid pGUID = player->GetGUID();
            uint32 characterID = pGUID.GetRawValue();
            CharacterDatabase.Query("INSERT INTO character_paragon (characterID, level, xp) VALUES ('{}', 0, 100)", characterID);
            CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina) VALUES ('{}', 0, 0, 0, 0 ,0)", characterID);
        }

    }

    void OnMapChanged(Player* player) override
    {
        if (!player->HasAura(AURA_PARAGONLEVEL))
        {
            ObjectGuid pGUID = player->GetGUID();
            uint32 characterID = pGUID.GetRawValue();
            QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE characterID = '{}'", characterID);
            if (qr) {
                uint32 paragonLevel = (*qr)[0].Get<uint32>();
                if (paragonLevel > 0) {
                    player->AddAura(AURA_PARAGONLEVEL, player);
                    player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
                }
                
            }
        }
    }

    void OnLevelChanged(Player* player, uint8 /*oldlevel*/) override
    {
        if (player->GetLevel() == 80 && !player->HasAura(AURA_PARAGONLEVEL))
        {
            //create entry in character_paragon
            ObjectGuid pGUID = player->GetGUID();
            uint32 characterID = pGUID.GetRawValue();
            QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE characterID = '{}'", characterID);
            if (!qr) {
                CharacterDatabase.Query("INSERT INTO character_paragon (characterID, level, xp) VALUES ('{}', 0, 100)", characterID);
                CharacterDatabase.Query("INSERT INTO character_paragon_points (characterID, pstrength, pintellect, pagility, pspirit, pstamina) VALUES ('{}', 0, 0, 0, 0 ,0)", characterID);
            }
        }
    }

    void OnPlayerResurrect(Player* player, float /*restore_percent*/, bool /*applySickness*/) override
    {
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE characterID = '{}'", characterID);
        if (qr) {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            if (paragonLevel > 0) {
                player->AddAura(AURA_PARAGONLEVEL, player);
                player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);
            }
            
        }
    }

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
            if ((killed->GetLevel() - killer->GetLevel() >= 0) || !killed->IsSummon() || killed->IsPet()) {
                bool isElite = killed->isElite(), isDungeon = killed->GetMap()->IsDungeon(), isRaid = killed->GetMap()->IsRaid(), isWorldBoss = killed->isWorldBoss(), isHeroic = killed->GetMap()->IsHeroic(), isDungeonBoss = killed->IsDungeonBoss();

                // normal elite: 1
                if (isElite && (!isDungeon || !isRaid) && !isWorldBoss) {
                    xpAmount = 1;
                }

                //world boss: 20
                else if (isElite && (!isDungeon || !isRaid) && isWorldBoss) {
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

    void IncreaseParagonXP(Player* player, uint8 value)
    {
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        QueryResult qr = CharacterDatabase.Query("Select level, xp FROM character_paragon WHERE characterID = '{}'", characterID);
        if (qr) {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            uint32 paragonXP = (*qr)[1].Get<uint32>();
            if ((paragonXP - value) <= 0)
            {
                uint32 xpLeft = (paragonXP - value) * (-1);
                uint32 newXP = 100 * (pow(1.1, paragonLevel + 1)) - xpLeft;
                //level up
                QueryResult qr = CharacterDatabase.Query("UPDATE character_paragon SET xp = '{}', level = level + 1 WHERE characterID = '{}'", newXP, characterID);
                player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel + 1);

                std::ostringstream ss;
                ss << "Congratulations " << player->GetName() << "! You increased your paragon level to " << paragonLevel + 1 << ".";
                ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                player->AddItem(920920, 5);
            }
            else {
                //update xp
                QueryResult qr = CharacterDatabase.Query("UPDATE character_paragon SET xp = xp - '{}' WHERE characterID = '{}'", value, characterID);
                if (debug) {
                    std::ostringstream ss;
                    uint32 xpGain = value;
                    ss << "Increasing paragon xp by " << xpGain << ". " << paragonXP - value << " needed to level up.";
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
