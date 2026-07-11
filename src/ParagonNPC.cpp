#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "GossipDef.h"
#include "ScriptedGossip.h"
#include "CharacterDatabase.h"
#include "ParagonUtils.h"

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

    bool OnGossipSelect(Player* player, Creature* creature, uint32 Sender, uint32 action) override
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

    void ResetParagonPoints(Player* player)
    {
        uint32 characterID = player->GetGUID().GetCounter();
        CharacterDatabasePreparedStatement* stmt =
            CharacterDatabase.GetPreparedStatement(
                CHAR_UPD_PARAGON_POINTS_RESET);
        stmt->SetData(0, characterID);
        CharacterDatabase.Execute(stmt);

        // Apply zero directly (race-free): the reset write above is async, so
        // re-reading the DB here could observe the pre-reset row.
        ClearParagonStats(player);
        ChatHandler(player->GetSession()).SendSysMessage(
            "Your Paragon points have been reset.");
    }
};

// Add all scripts in one
void AddParagonNPCScripts()
{
    new ParagonNPC();
}