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
    AURA_STRENGTH = 100001,
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
        uint32 accountID = player->GetSession()->GetAccountId();
        QueryResult qr = CharacterDatabase.Query("Select level FROM character_paragon WHERE accountID = '{}'", accountID);
        if (qr) {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            player->AddAura(AURA_PARAGONLEVEL, player);
            player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel);

            //load paragon points
            // AttributesAuraIds = { 7464, 7471, 7477, 7468, 7474 } -- Strength, Agility, Stamina, Intellect, Spirit
            QueryResult qrtwo = CharacterDatabase.Query("Select * FROM character_paragon_points WHERE accountID = '{}'", accountID);
            if (qrtwo) {
                uint32 pstrength = (*qrtwo)[1].Get<uint32>();
                uint32 pintellect = (*qrtwo)[2].Get<uint32>();
                uint32 pagility = (*qrtwo)[3].Get<uint32>();
                uint32 pspirit = (*qrtwo)[4].Get<uint32>();
                uint32 pstamina = (*qrtwo)[5].Get<uint32>();

                //check for corrupted points
                uint32 unspentPoints = player->GetItemCount(100000);
                if (pstrength + pintellect + pagility + pspirit + pstamina + unspentPoints != paragonLevel * 5) {
                    CharacterDatabase.Execute("UPDATE character_paragon_points SET pstrength = 0, pintellect = 0, pagility = 0, pspirit = 0, pstamina = 0 WHERE accountID = '{}'", accountID);
                    ChatHandler(player->GetSession()).SendSysMessage("There was an error loading your paragon points, please reallocate them!");
                    player->AddItem(100000, paragonLevel * 5 - unspentPoints);
                }

                player->AddAura(AURA_STRENGTH, player);
                player->SetAuraStack(AURA_STRENGTH, player, pstrength);
                player->AddAura(AURA_INTELLECT, player);
                player->SetAuraStack(AURA_INTELLECT, player, pstrength);
                player->AddAura(AURA_AGILITY, player);
                player->SetAuraStack(AURA_AGILITY, player, pstrength);
                player->AddAura(AURA_SPIRIT, player);
                player->SetAuraStack(AURA_SPIRIT, player, pstrength);
                player->AddAura(AURA_STAMINA, player);
                player->SetAuraStack(AURA_STAMINA, player, pstrength);

                
            }

        }
        else if(player->GetLevel() == 80) {
            uint32 accountID = player->GetSession()->GetAccountId();
            CharacterDatabase.Query("INSERT INTO character_paragon (accountID, level, xp) VALUES ('{}', 0, 100)", accountID);
            CharacterDatabase.Query("INSERT INTO character_paragon_points (accountID, pstrength, pintellect, pagility, pspirit, pstamina) VALUES ('{}', 0, 0, 0, 0 ,0)", accountID);
            player->AddAura(AURA_PARAGONLEVEL, player);
        }

    }



    void OnLevelChanged(Player* player, uint8 /*oldlevel*/) override
    {
        if (player->GetLevel() == 80)
        {
            //create entry in character_paragon
            uint32 accountID = player->GetSession()->GetAccountId();
            CharacterDatabase.Query("INSERT INTO character_paragon (accountID, level, xp) VALUES ('{}', 0, 100)", accountID);
            CharacterDatabase.Query("INSERT INTO character_paragon_points (accountID, pstrength, pintellect, pagility, pspirit, pstamina) VALUES ('{}', 0, 0, 0, 0 ,0)", accountID);
            player->AddAura(AURA_PARAGONLEVEL, player);
        }
    }

    void OnCreatureKill(Player* killer, Creature* killed) override
    {
        //increase xp
        if (killed->IsDungeonBoss() && (killed->GetLevel()-killer->GetLevel()) > 0)
        {
            //party xp
            
            if (Group* myGroup = killer->GetGroup()) {
                Group::MemberSlotList const& groupMembers = myGroup->GetMemberSlots();
                
                for (auto member = groupMembers.begin(); member != groupMembers.end(); ++member)
                {
                    if (Player* player = ObjectAccessor::GetPlayer(killer->GetMap(), member->guid)) {
                        IncreaseParagonXP(player, 3);
                    }
                }
            }
            else {
                IncreaseParagonXP(killer, 3);
            }

        }
        else if (killed->isElite() && (killed->GetLevel() - killer->GetLevel()) > 0 && !killed->IsSummon())
        {
            IncreaseParagonXP(killer, 1);
        }
    }

    void OnCreatureKilledByPet(Player* killer, Creature* killed) override
    {
        if (killed->IsDungeonBoss() && (killed->GetLevel() - killer->GetLevel()) > 0)
        {
            //party xp

            if (Group* myGroup = killer->GetGroup()) {
                Group::MemberSlotList const& groupMembers = myGroup->GetMemberSlots();

                for (auto member = groupMembers.begin(); member != groupMembers.end(); ++member)
                {
                    if (Player* player = ObjectAccessor::GetPlayer(killer->GetMap(), member->guid)) {
                        IncreaseParagonXP(player, 3);
                    }
                }
            }
            else {
                IncreaseParagonXP(killer, 3);
            }

        }
        else if (killed->isElite() && (killed->GetLevel() - killer->GetLevel()) > 0 && !killed->IsSummon())
        {
            IncreaseParagonXP(killer, 1);
        }
    }

    // On Quest reward

    void IncreaseParagonXP(Player* player, uint8 value)
    {
        uint32 accountID = player->GetSession()->GetAccountId();
        QueryResult qr = CharacterDatabase.Query("Select level, xp FROM character_paragon WHERE accountID = '{}'", accountID);
        if (qr) {
            uint32 paragonLevel = (*qr)[0].Get<uint32>();
            uint32 paragonXP = (*qr)[1].Get<uint32>();
            if ((paragonXP - value) <= 0)
            {
                uint32 xpLeft = (paragonXP - value) * (-1);
                uint32 newXP = 100 * (pow(1.1, paragonLevel + 1)) - xpLeft;
                //level up
                QueryResult qr = CharacterDatabase.Query("UPDATE character_paragon SET xp = '{}', level = level + 1 WHERE accountID = '{}'", newXP, accountID);
                player->SetAuraStack(AURA_PARAGONLEVEL, player, paragonLevel + 1);

                std::ostringstream ss;
                ss << "Congratulations " << player->GetName() << "! You increased your paragon level to " << paragonLevel + 1 << ".";
                ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
                player->AddItem(100000, 5);
            }
            else {
                //update xp
                QueryResult qr = CharacterDatabase.Query("UPDATE character_paragon SET xp = xp - '{}' WHERE accountID = '{}'", value, accountID);
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
