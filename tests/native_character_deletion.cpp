/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 * Released under the GNU General Public License, version 2 or later.
 */

#include "CharacterCache.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "MySQLThreading.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "World.h"
#include <iostream>
#include <stdexcept>
#ifdef _WIN32
#include <windows.h>
#endif

void AddParagonPlayerScripts();

static bool failDeletion = false;

class FailureFixture : public PlayerScript
{
public:
    FailureFixture() : PlayerScript("ParagonDeleteFailureFixture",
        { PLAYERHOOK_ON_DELETE_FROM_DB }) { }

    void OnPlayerDeleteFromDB(CharacterDatabaseTransaction trans,
        uint32 /*guid*/) override
    {
        if (failDeletion)
            trans->Append("INSERT INTO `character_paragon` "
                "(`accountID`, `level`, `xp`) VALUES (1, 1, 1)");
    }
};

static uint32 Scalar(char const* query)
{
    QueryResult result = CharacterDatabase.Query(query);
    if (!result)
        throw std::runtime_error("Fixture query failed");
    return result->Fetch()[0].Get<uint32>();
}

static void Require(bool condition, char const* message)
{
    if (!condition)
        throw std::runtime_error(message);
}

static void Barrier()
{
    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("DO 1");
    auto callback = CharacterDatabase.AsyncCommitTransaction(trans);
    Require(callback.m_future.get(), "Async barrier failed");
}

static void Seed()
{
    CharacterDatabase.DirectExecute("DELETE FROM `characters`");
    CharacterDatabase.DirectExecute("DELETE FROM `character_paragon_points`");
    CharacterDatabase.DirectExecute("DELETE FROM `character_paragon`");
    CharacterDatabase.DirectExecute("INSERT INTO `characters` "
        "(`guid`, `account`, `name`, `level`, `taximask`, `innTriggerId`) VALUES "
        "(100, 1, 'Tbotdelete', 80, '', 0), (101, 1, 'Tbotkeep', 80, '', 0), "
        "(200, 2, 'Crtestkeep', 80, '', 0)");
    CharacterDatabase.DirectExecute("INSERT INTO `character_paragon` VALUES "
        "(1, 200, 12345), (2, 17, 4321)");
    CharacterDatabase.DirectExecute("INSERT INTO `character_paragon_points` "
        "(`characterID`, `pstrength`, `plifeleech`, `unspent_points`) VALUES "
        "(100, 23, 7, 11), (101, 29, 9, 13), (200, 31, 11, 17)");
    Require(Scalar("SELECT COUNT(*) FROM `characters`") == 3,
        "Fixture characters were not seeded");
    Require(Scalar("SELECT COUNT(*) FROM `character_paragon_points`") == 3,
        "Fixture allocations were not seeded");
    for (uint32 guid : { 100u, 101u, 200u })
    {
        auto objectGuid = ObjectGuid::Create<HighGuid::Player>(guid);
        if (!sCharacterCache->HasCharacterCacheEntry(objectGuid))
            sCharacterCache->AddCharacterCacheEntry(objectGuid,
                guid == 200 ? 2 : 1, "Fixture", 0, 1, 1, 80);
    }
}

static void Preserved()
{
    Require(Scalar("SELECT `xp` FROM `character_paragon` "
        "WHERE `accountID` = 1") == 12345, "Account XP changed");
    Require(Scalar("SELECT `level` FROM `character_paragon` "
        "WHERE `accountID` = 1") == 200, "Account level changed");
    Require(Scalar("SELECT SUM(`pstrength`) FROM `character_paragon_points` "
        "WHERE `characterID` IN (101, 200)") == 60,
        "Unrelated allocations changed");
}

static int Run(int argc, char** argv)
{
    std::cout << std::unitbuf;
    std::cerr << std::unitbuf;
    std::cout << "Native fixture starting\n";
#ifdef _WIN32
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
#endif
    if (argc != 4)
        return 2;
    MySQL::Library_Init();
    CharacterDatabase.SetConnectionInfo(
        "127.0.0.1;13368;root;;paragon_delete_native", 1, 1);
    if (CharacterDatabase.Open())
        return 3;
    auto datadir = CharacterDatabase.Query("SELECT @@datadir");
    Require(datadir && datadir->Fetch()[0].Get<std::string>() == argv[1],
        "Refusing non-scratch server");
    Require(CharacterDatabase.PrepareStatements(), "PrepareStatements failed");
    std::cout << "Native database statements prepared\n";
    AddParagonPlayerScripts();
    new FailureFixture();
    sConfigMgr->Configure(argv[2], {});
    Require(sConfigMgr->LoadAppConfigs(), "Fixture config load failed");
    std::cout << "Native fixture configuration loaded\n";
    sWorld->LoadConfigSettings();
    std::cout << "Native world configuration initialized\n";
    Require(sConfigMgr->GetOption<bool>("Paragon.Enable", false),
        "Initial fixture must enable Paragon");
    sWorld->setIntConfig(CONFIG_CHARDELETE_MIN_LEVEL, 0);
    sWorld->setIntConfig(CONFIG_CHARDELETE_METHOD, CHAR_DELETE_UNLINK);

    Seed();
    Player::DeleteFromDB(100, 1, false, true);
    Barrier();
    Require(Scalar("SELECT COUNT(*) FROM `characters` WHERE `guid` = 100") == 0,
        "Permanent character deletion failed");
    Require(Scalar("SELECT COUNT(*) FROM `character_paragon_points` "
        "WHERE `characterID` = 100") == 0, "Allocation survived permanent deletion");
    Preserved();
    std::cout << "PASS native permanent deletion and account/unrelated preservation\n";

    Seed();
    Player::DeleteFromDB(100, 1, false, false);
    Barrier();
    Require(Scalar("SELECT `account` FROM `characters` WHERE `guid` = 100") == 0,
        "Soft deletion failed");
    Require(Scalar("SELECT `deleteInfos_Account` FROM `characters` "
        "WHERE `guid` = 100") == 1, "Restore account missing");
    Require(Scalar("SELECT `pstrength` FROM `character_paragon_points` "
        "WHERE `characterID` = 100") == 23, "Soft deletion lost allocation");
    Preserved();
    std::cout << "PASS native soft deletion preserves allocation\n";

    Player::DeleteFromDB(100, 1, false, true);
    Barrier();
    Require(Scalar("SELECT COUNT(*) FROM `character_paragon_points` "
        "WHERE `characterID` = 100") == 0, "Soft-deleted purge lost cleanup");
    Preserved();
    std::cout << "PASS native permanent purge of soft-deleted character\n";

    Seed();
    failDeletion = true;
    Player::DeleteFromDB(100, 1, false, true);
    Barrier();
    Require(Scalar("SELECT COUNT(*) FROM `characters` WHERE `guid` = 100") == 1,
        "Failed transaction deleted character");
    Require(Scalar("SELECT `pstrength` FROM `character_paragon_points` "
        "WHERE `characterID` = 100") == 23, "Failed transaction deleted allocation");
    Preserved();
    std::cout << "PASS native transaction failure rolls back core and Paragon deletion\n";
    failDeletion = false;
    sConfigMgr->Configure(argv[3], {});
    Require(sConfigMgr->LoadAppConfigs(), "Fixture config load failed");
    sScriptMgr->OnAfterConfigLoad(false);
    Require(!sConfigMgr->GetOption<bool>("Paragon.Enable", true),
        "Fixture must disable Paragon");
    Seed();
    Player::DeleteFromDB(100, 1, false, true);
    Barrier();
    Require(Scalar("SELECT COUNT(*) FROM `character_paragon_points` "
        "WHERE `characterID` = 100") == 0, "Disabled Paragon lost cleanup");
    Preserved();
    std::cout << "PASS native cleanup while Paragon is disabled\n";
    CharacterDatabase.Close();
    MySQL::Library_End();
    return 0;
}

int main(int argc, char** argv)
{
    try
    {
        return Run(argc, argv);
    }
    catch (std::exception const& error)
    {
        std::cerr << "FAIL " << error.what() << std::endl;
        CharacterDatabase.Close();
        MySQL::Library_End();
        return 1;
    }
}
