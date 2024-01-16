#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "GossipDef.h"
#include "ScriptedGossip.h"

uint32 gossip_text = 197760;

class ParagonNPC : public CreatureScript
{
public:
    ParagonNPC() : CreatureScript("npc_paragon") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        player->PlayerTalkClass->ClearMenus();

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "How does the Abyssal Mastery work?", GOSSIP_SENDER_MAIN, 1);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Reset my allocated points.", GOSSIP_SENDER_MAIN, 2);


        SendGossipMenuFor(player, gossip_text, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 Sender, uint32 action)
    {
        player->PlayerTalkClass->ClearMenus();

        switch (action)
        {
        case 1:

            break;

        case 2:
            ResetParagonPoints(player);
            break;
        }
        SendGossipMenuFor(player, gossip_text, creature->GetGUID());



        return true;
    }

    void ResetParagonPoints(Player* player) {
        ObjectGuid pGUID = player->GetGUID();
        uint32 characterID = pGUID.GetRawValue();
        uint32 accountID = player->GetSession()->GetAccountId();
        CharacterDatabase.Execute("UPDATE character_paragon_points SET pstrength = 0, pintellect = 0, pagility = 0, pspirit = 0, pstamina = 0 WHERE characterID = '{}'", characterID);
        player->GetSession()->LogoutPlayer(true);
    }
};

// Add all scripts in one
void AddMyNPCScripts()
{
    new ParagonNPC();
}