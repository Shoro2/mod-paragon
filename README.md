# mod-paragon

Post-level-80 progression system ("Paragon") for an [AzerothCore](https://www.azerothcore.org/) **WoW 3.3.5a (WotLK)** server. Part of the Forgotten Land server project.

Once a character reaches the regular level cap (80), they keep gaining experience from creature kills, quests and bosses. Each Paragon level grants 5 unspent points the player distributes across **17 stats**:

- **Primary stats**: Strength, Intellect, Agility, Spirit, Stamina
- **Combat ratings**: Haste, Crit, Hit, Expertise, Block, Parry, Dodge, ArmorPen
- **Magic**: SpellPower, ManaRegen
- **Mobility**: MountSpeed
- **Special**: LifeLeech (heals a configurable percentage of damage dealt, also through pets, totems and charmed units)

Paragon level and XP are **account-wide**; the stat allocation is **per character**, so each alt can pick its own focus.

## Features

- Post-80 XP from creature kills, quests and bosses, with a configurable reward per encounter type (elite, dungeon elite/boss, heroic dungeon elite/boss, raid boss, world boss, daily quest).
- Group-aware XP: kills on the same map credit all group members; optional XP reduction by party size.
- Per-stat point caps (configurable, 0 = unlimited). Stats are applied once with their full value through the core stat APIs, so there is no 255 stack ceiling.
- In-game UI built on [AIO](https://github.com/Rochet2/AIO): the `/paragon` command, an ESC-menu button, and an optional gossip NPC (script `npc_paragon`) that offers info and a point reset.
- State in `acore_characters`: `character_paragon` (account level and XP) and `character_paragon_points` (per-character allocation).
- Other modules can read the true Paragon level through `GetParagonLevel(Player*)` (the level marker aura 100000 caps at a 255 stack and must not be used for this).

## How it works

- **XP**: a character at level 80 earns Paragon XP per kill or quest, by encounter type (defaults: regular elite 1, dungeon elite 1, heroic dungeon elite 2, dungeon boss 3, heroic dungeon boss 5, raid boss 10, world boss 20, daily/weekly quest 3). Each member of a group on the same map gets the credit. The XP needed for a level grows by 10 % per level (`100 * 1.1^(level-1)`).
- **Points**: every Paragon level adds `Paragon.PPL` (5) unspent points. Points are spent in the window, one at a time, up to the per-stat cap; the NPC or the window can reset them.
- **Value per point**: Strength, Intellect, Agility, Spirit, Stamina, Haste, ArmorPen and ManaRegen give 5 each; SpellPower, Crit, Hit, Parry and Dodge 10; Block 4; Expertise 3; MountSpeed 1; LifeLeech `Paragon.LifeLeechPct` percent of damage dealt as healing.
- **Application**: stats are applied once with their full value through the core's stat modifiers and rating system on login and after every allocation or reset, so the usual 255 aura-stack limit does not apply.
- **Account vs. character**: level and XP are stored per account, the allocation per character; a new alt starts with the account's level and the matching number of unspent points.

## Requirements

- AzerothCore WotLK, **the [Shoro2/azerothcore-wotlk](https://github.com/Shoro2/azerothcore-wotlk) fork**. The module uses prepared statements (`CHAR_SEL_PARAGON_*`, `CHAR_INS_PARAGON*`, `CHAR_UPD_PARAGON_*`, `CHAR_DEL_PARAGON_POINTS`) that live in the core's `CharacterDatabase`, so it does not build against upstream AzerothCore. Build core and module together.
- A Lua engine module ([mod-ale](https://github.com/azerothcore/mod-ale), Eluna-compatible) and the [AIO framework](https://github.com/Rochet2/AIO) (server side and client addon) for the UI.
- Companion module (optional): [mod-paragon-itemgen](https://github.com/Shoro2/mod-paragon-itemgen) reads the Paragon level to scale bonus stats on items.

## Installation

1. Clone the module into the `modules/` directory of the server source:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Shoro2/mod-paragon.git
   ```
2. Re-run CMake and rebuild the server.
3. SQL: the files under `data/sql/db-characters/` and `data/sql/db-world/` (`base/` and `updates/`) are applied by the AzerothCore DB updater on the next server start.
4. Copy `conf/mod_paragon.conf.dist` to your server's module config folder as `mod_paragon.conf` and adjust it.
5. Copy the Lua files from `Paragon_System_LUA/` (`Paragon_Server.lua`, `Paragon_Client.lua`, `Paragon_Data.lua`) into the server's `lua_scripts/` folder (for example `lua_scripts/Paragon_System/`). The client UI is delivered to players by AIO; players need the AIO client addon.
6. Restart the world server. Check with the Paragon NPC, `/paragon`, or the ESC-menu "Paragon" button.

## Configuration

`conf/mod_paragon.conf.dist` documents all keys. The main ones:

- `Paragon.Enable` - master toggle.
- `Paragon.MaxLevel` - level cap (0 = unlimited).
- `Paragon.PPL` - points per level (default 5).
- XP rewards: `Paragon.XPElite`, `XPWorldBoss`, `XPDungeonElite`, `XPDungeonBoss`, `XPHCDungeonElite`, `XPHCDungeonBoss`, `XPRaidBoss`, `XPQuest`; `Paragon.XPPartyReduce` divides XP by the party size.
- Per-stat caps: `Paragon.MaxStr`, `Paragon.MaxInt`, `Paragon.MaxAgi`, ... (0 = unlimited).
- `Paragon.LifeLeechPct` - percentage of damage healed per Life Leech point.
- `Paragon.IdLevel`, `Paragon.MountSpeedSpellId` - spell IDs of the level marker and the mount-speed aura.

## Usage

- `/paragon` (client) or the ESC-menu "Paragon" button opens the window, where unspent points are allocated to stats.
- Optional gossip NPC: the module registers the creature script `npc_paragon` (info / reset all points to unspent) but does not ship a `creature_template` row. To use it, set `ScriptName = 'npc_paragon'` on a creature template of your choice (gossip greeting text id `197760`).

## License

MIT (see `LICENSE`).
