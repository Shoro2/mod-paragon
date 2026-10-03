"""Prepare a fresh native fixture on an explicitly guarded private MySQL server."""
import argparse
import pathlib
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--mysql", required=True)
parser.add_argument("--core", type=pathlib.Path, required=True)
parser.add_argument("--scratch-datadir", type=pathlib.Path, required=True)
args = parser.parse_args()


def mysql(query, database=None):
    command = [args.mysql, "--no-defaults", "--protocol=TCP", "--host=127.0.0.1",
               "--port=13368", "--user=root", "--skip-password", "--batch",
               "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=query, capture_output=True,
                            encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()


actual = mysql("SELECT @@datadir;")
if pathlib.Path(actual).resolve() != args.scratch_datadir.resolve():
    raise SystemExit("Refusing a non-scratch server")
if mysql("SELECT COUNT(*) FROM information_schema.schemata "
         "WHERE schema_name='paragon_delete_native';") != "0":
    raise SystemExit("Native fixture exists; use a fresh private server")
mysql("CREATE DATABASE paragon_delete_native;")
for file in sorted((args.core / "data/sql/base/db_characters").glob("*.sql")):
    # Schema only: never import any existing account/character data.
    creates = re.findall(r"CREATE TABLE.*?\) ENGINE=.*?;",
                         file.read_text(encoding="utf-8"), re.S)
    mysql("SET FOREIGN_KEY_CHECKS=0;\n" + "\n".join(creates),
          "paragon_delete_native")
module = pathlib.Path(__file__).resolve().parents[1]
for file in (module / "data/sql/db-characters/base").glob("*.sql"):
    mysql(file.read_text(), "paragon_delete_native")

# Inert tables needed to prepare the fork's other custom statements; no other
# module is linked into the fixture and no gameplay data is imported.
mysql("""
CREATE TABLE character_forgotten_power (guid INT PRIMARY KEY, total_power BIGINT,
    selected_loadout INT, revision INT);
CREATE TABLE character_forgotten_loadout (guid INT, loadout_id INT, name VARCHAR(24),
    revision INT, spent_power BIGINT, PRIMARY KEY(guid,loadout_id));
CREATE TABLE character_forgotten_node (guid INT, loadout_id INT, node_id INT,
    `rank` INT, PRIMARY KEY(guid,loadout_id,node_id));
CREATE TABLE character_forgotten_grant (guid INT, spell_id INT);
CREATE TABLE character_forgotten_purchase (guid INT, node_id INT, `rank` INT,
    t1 INT,t2 INT,t3 INT,t4 INT,t5 INT);
CREATE TABLE character_paragon_role (characterID INT PRIMARY KEY, role INT, mainStat INT);
CREATE TABLE character_paragon_spec (characterId INT PRIMARY KEY, specId INT);
CREATE TABLE character_paragon_item (itemGuid INT PRIMARY KEY, paragonLevel INT,
    role INT,mainStat INT,combatRating1 INT,combatRating2 INT,statAmount INT,
    cursed INT,passiveSpellEnchantId INT);
CREATE TABLE test_accounts (id INT PRIMARY KEY, username VARCHAR(20));
INSERT INTO test_accounts VALUES (1,'TBOT00'),(2,'CRTEST1');
""", "paragon_delete_native")
print(f"Prepared native fixture, verified @@datadir = {actual}")
