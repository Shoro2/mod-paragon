"""Offline MySQL fixtures; never connect this runner to a shared server."""

import argparse
import os
import pathlib
import re
import subprocess
import unittest

PARSER = argparse.ArgumentParser(description=__doc__)
PARSER.add_argument("--mysql", required=True)
PARSER.add_argument("--port", type=int, required=True)
PARSER.add_argument("--scratch-datadir", type=pathlib.Path, required=True)
PARSER.add_argument("--core", type=pathlib.Path, required=True)
ARGS = PARSER.parse_args()
MODULE = pathlib.Path(__file__).resolve().parents[1]
DATABASE = f"paragon_delete_fixture_{os.getpid()}"


def mysql(sql, database=None, fail=False):
    command = [ARGS.mysql, "--no-defaults", "--protocol=TCP", "--host=127.0.0.1",
               f"--port={ARGS.port}", "--user=root", "--skip-password",
               "--batch", "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=sql, capture_output=True,
                            text=True, encoding="utf-8", errors="replace")
    if fail:
        assert result.returncode != 0, "Expected a transaction failure"
    elif result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()


# Validate the server itself before any write, not just its database name/port.
actual_datadir = pathlib.Path(mysql("SELECT @@datadir;")).resolve()
if actual_datadir != ARGS.scratch_datadir.resolve() or ARGS.port == 3306:
    raise SystemExit("Refusing a server other than the explicit scratch datadir")
if mysql(f"SELECT COUNT(*) FROM information_schema.schemata WHERE "
         f"schema_name = '{DATABASE}';") != "0":
    raise SystemExit("Fixture database already exists; use a fresh scratch server")

implementation = (ARGS.core / "src/server/database/Database/Implementation/"
                  "CharacterDatabase.cpp").read_text(encoding="utf-8")
match = re.search(r'PrepareStatement\(CHAR_DEL_PARAGON_POINTS, "([^"]+)", '
                  r'CONNECTION_ASYNC\);', implementation)
if not match:
    raise SystemExit("Missing async Paragon deletion statement")
DELETE_SQL = match[1]
MIGRATION = (MODULE / "data/sql/db-characters/updates/"
             "cleanup_orphan_paragon_points_2026_10_03.sql").read_text()


def sql(text, fail=False):
    return mysql(text, DATABASE, fail)


def delete_allocation(guid):
    return (f"PREPARE paragon_delete FROM '{DELETE_SQL}'; "
            f"SET @guid = {guid}; EXECUTE paragon_delete USING @guid; "
            "DEALLOCATE PREPARE paragon_delete;")


class CharacterDeletion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        mysql(f"CREATE DATABASE `{DATABASE}`;")
        sql("CREATE TABLE test_accounts (id INT PRIMARY KEY, username "
            "VARCHAR(20)); INSERT INTO test_accounts VALUES "
            "(1, 'TBOT00'), (2, 'CRTEST1'), (3, 'TBOT01'); "
            "CREATE TABLE characters (guid INT PRIMARY KEY, account INT, "
            "name VARCHAR(20), deleteInfos_Account INT DEFAULT NULL, "
            "deleteInfos_Name VARCHAR(20) DEFAULT NULL, "
            "deleteDate BIGINT DEFAULT NULL) ENGINE=InnoDB;")
        for name in ("character_paragon_create.sql",
                     "character_paragon_points_create.sql"):
            sql((MODULE / "data/sql/db-characters/base" / name).read_text())

    def setUp(self):
        sql("DELETE FROM characters; DELETE FROM character_paragon_points; "
            "DELETE FROM character_paragon; "
            "INSERT INTO characters (guid,account,name) VALUES "
            "(100,1,'Tbotdelete'), (101,1,'Tbotkeep'), (200,2,'Crtestkeep'), "
            "(300,3,'Tbotlast'); "
            "INSERT INTO character_paragon VALUES "
            "(1,200,12345), (2,17,4321), (3,666,98765); "
            "INSERT INTO character_paragon_points "
            "(characterID,unspent_points,pstrength,plifeleech) VALUES "
            "(100,11,23,7), (101,13,29,9), (200,17,31,11), (300,19,37,13);")
        self.progress = sql("SELECT * FROM character_paragon ORDER BY accountID;")
        self.unrelated = sql("SELECT * FROM character_paragon_points "
                             "WHERE characterID IN (101,200) ORDER BY characterID;")

    def assert_preserved(self):
        self.assertEqual(self.progress,
                         sql("SELECT * FROM character_paragon ORDER BY accountID;"))
        self.assertEqual(self.unrelated,
                         sql("SELECT * FROM character_paragon_points "
                             "WHERE characterID IN (101,200) ORDER BY characterID;"))

    def test_original_bug_and_guid_reuse(self):
        sql("DELETE FROM characters WHERE guid=100;")
        self.assertEqual(sql("SELECT pstrength FROM character_paragon_points "
                             "WHERE characterID=100;"), "23")
        result = subprocess.run(
            [ARGS.mysql, "--no-defaults", "--protocol=TCP", "--host=127.0.0.1",
             f"--port={ARGS.port}", "--user=root", "--skip-password", DATABASE],
            input="INSERT INTO character_paragon_points (characterID) VALUES (100);",
            capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Duplicate entry", result.stderr)
        sql(MIGRATION)
        sql("INSERT INTO characters (guid,account,name) VALUES (100,1,'Tbotnew');"
            "INSERT INTO character_paragon_points (characterID) VALUES (100);")
        self.assertEqual(sql("SELECT pstrength,plifeleech FROM "
                             "character_paragon_points WHERE characterID=100;"), "0\t0")
        self.assert_preserved()

    def test_permanent_delete_commits_both_rows(self):
        sql("START TRANSACTION; DELETE FROM characters WHERE guid=100; "
            + delete_allocation(100) + " COMMIT;")
        self.assertEqual(sql("SELECT COUNT(*) FROM character_paragon_points "
                             "WHERE characterID=100;"), "0")
        self.assertEqual(sql("SELECT COUNT(*) FROM characters WHERE guid=100;"), "0")
        sql("INSERT INTO characters (guid,account,name) VALUES (100,1,'Tbotnew');"
            "INSERT INTO character_paragon_points (characterID) VALUES (100);")
        self.assertEqual(sql("SELECT pstrength FROM character_paragon_points "
                             "WHERE characterID=100;"), "0")
        self.assert_preserved()

    def test_soft_delete_migration_and_restore(self):
        allocation = sql("SELECT * FROM character_paragon_points WHERE characterID=100;")
        sql("UPDATE characters SET deleteInfos_Account=account, "
            "deleteInfos_Name=name, deleteDate=123456789, account=0, name='' "
            "WHERE guid=100;")
        sql(MIGRATION)
        self.assertEqual(allocation, sql("SELECT * FROM character_paragon_points "
                                         "WHERE characterID=100;"))
        sql("UPDATE characters SET account=deleteInfos_Account, "
            "name=deleteInfos_Name, deleteInfos_Account=NULL, "
            "deleteInfos_Name=NULL, deleteDate=NULL WHERE guid=100;")
        self.assertEqual(allocation, sql("SELECT * FROM character_paragon_points "
                                         "WHERE characterID=100;"))
        self.assert_preserved()

    def test_last_character_keeps_account_progress(self):
        sql("START TRANSACTION; DELETE FROM characters WHERE guid=300; "
            + delete_allocation(300) + " COMMIT;")
        self.assertEqual(sql("SELECT COUNT(*) FROM characters WHERE account=3;"), "0")
        self.assert_preserved()

    def test_missing_allocation_is_harmless(self):
        sql("DELETE FROM character_paragon_points WHERE characterID=100;")
        sql("START TRANSACTION; DELETE FROM characters WHERE guid=100; "
            + delete_allocation(100) + " COMMIT;")
        self.assert_preserved()

    def test_explicit_rollback_restores_both_rows(self):
        before = sql("SELECT * FROM character_paragon_points ORDER BY characterID;")
        sql("START TRANSACTION; DELETE FROM characters WHERE guid=100; "
            + delete_allocation(100) + " ROLLBACK;")
        self.assertEqual(before, sql("SELECT * FROM character_paragon_points "
                                     "ORDER BY characterID;"))
        self.assertEqual(sql("SELECT COUNT(*) FROM characters WHERE guid=100;"), "1")
        self.assert_preserved()

    def test_failure_after_cleanup_rolls_back(self):
        sql("START TRANSACTION; DELETE FROM characters WHERE guid=100; "
            + delete_allocation(100)
            + " INSERT INTO characters (guid,account,name) VALUES (101,1,'Duplicate'); "
            "COMMIT;", fail=True)
        # The client aborts on the duplicate key; disconnect rolls back InnoDB.
        self.assertEqual(sql("SELECT COUNT(*) FROM characters WHERE guid=100;"), "1")
        self.assertEqual(sql("SELECT pstrength FROM character_paragon_points "
                             "WHERE characterID=100;"), "23")
        self.assert_preserved()

    def test_migration_orphans_only_and_idempotent(self):
        sql("INSERT INTO character_paragon_points (characterID,pstrength) "
            "VALUES (999,47), (998,43); UPDATE characters SET "
            "deleteInfos_Account=account, deleteInfos_Name=name, deleteDate=123, "
            "account=0,name='' WHERE guid=100;")
        before = sql("SELECT * FROM character_paragon_points WHERE "
                     "characterID<998 ORDER BY characterID;")
        sql(MIGRATION)
        self.assertEqual(sql("SELECT COUNT(*) FROM character_paragon_points "
                             "WHERE characterID IN (998,999);"), "0")
        self.assertEqual(before, sql("SELECT * FROM character_paragon_points "
                                     "ORDER BY characterID;"))
        sql(MIGRATION)
        self.assertEqual(before, sql("SELECT * FROM character_paragon_points "
                                     "ORDER BY characterID;"))
        self.assert_preserved()

    def test_migration_is_transactional(self):
        sql("INSERT INTO character_paragon_points (characterID) VALUES (999);")
        sql("START TRANSACTION; " + MIGRATION + " ROLLBACK;")
        self.assertEqual(sql("SELECT COUNT(*) FROM character_paragon_points "
                             "WHERE characterID=999;"), "1")
        self.assert_preserved()

    def test_fresh_database_updater_order(self):
        files = sorted((MODULE / "data/sql/db-characters").rglob("*.sql"),
                       key=lambda file: file.name)
        migration = next(file for file in files if file.name.startswith("cleanup_orphan"))
        for name in ("character_paragon_create.sql",
                     "character_paragon_points_create.sql"):
            self.assertLess(files.index(next(file for file in files if file.name == name)),
                            files.index(migration))
        fresh = DATABASE + "_fresh"
        mysql(f"CREATE DATABASE `{fresh}`;")
        mysql("CREATE TABLE characters (guid INT PRIMARY KEY) ENGINE=InnoDB;", fresh)
        for file in files:
            if file.name in ("character_paragon_create.sql",
                             "character_paragon_points_create.sql", migration.name):
                mysql(file.read_text(), fresh)
        self.assertEqual(mysql("SELECT COUNT(*) FROM character_paragon_points;", fresh), "0")

    def test_hook_and_core_transaction_contract(self):
        player = (MODULE / "src/ParagonPlayer.cpp").read_text(encoding="utf-8")
        hook = player.split("void OnPlayerDeleteFromDB(", 1)[1].split(
            "void OnPlayerLogin(", 1)[0]
        self.assertIn("transaction->Append(stmt);", hook)
        self.assertIn("stmt->SetData(0, guid);", hook)
        self.assertNotIn("conf_Enable", hook)
        self.assertNotIn("CharacterDatabase.Execute", hook)
        self.assertNotIn("CommitTransaction", hook)
        core = (ARGS.core / "src/server/game/Entities/Player/Player.cpp").read_text()
        permanent = core.split("case CHAR_DELETE_REMOVE:", 1)[1].split(
            "case CHAR_DELETE_UNLINK:", 1)[0]
        self.assertLess(permanent.index("OnPlayerDeleteFromDB(trans, lowGuid)"),
                        permanent.index("CommitTransaction(trans)"))
        soft = core.split("case CHAR_DELETE_UNLINK:", 1)[1].split("default:", 1)[0]
        self.assertNotIn("OnPlayerDeleteFromDB", soft)


if __name__ == "__main__":
    unittest.main(argv=[__file__], verbosity=2)
