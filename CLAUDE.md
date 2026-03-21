# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Zentrales Projekt-Wiki**: Dieses Modul ist Teil eines Multi-Repo WoW-Server-Projekts. Die übergreifende Dokumentation, Zusatzinfos und Python-Tools befinden sich im [share-public](https://github.com/Shoro2/share-public) Repository:
> - [`CLAUDE.md`](https://github.com/Shoro2/share-public/blob/main/CLAUDE.md) — Gesamtarchitektur, SpellScript/DBC-Referenz, alle Custom-IDs, Modul-Übersicht, **komplette DB-Struktur (304 Tabellen)**, **DBC-Inventar (246 Dateien)**
> - [`claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md) — Änderungshistorie, Projektpläne, priorisierte TODOs
> - [`python_scripts/`](https://github.com/Shoro2/share-public/tree/main/python_scripts) — DBC-Patching-Tools (`patch_dbc.py`, `copy_spells_dbc.py`), Paragon-Spell-Generator (`add_paragon_spell.py`)
> - [`dbc/`](https://github.com/Shoro2/share-public/tree/main/dbc) — Alle 246 WoW-Client DBC-Dateien (Spell.dbc, SpellItemEnchantment.dbc, etc.)
> - [`mysqldbextracts/`](https://github.com/Shoro2/share-public/tree/main/mysqldbextracts) — Komplette DB-Spaltenstruktur (`mysql_column_list_all.txt`), CSV-Exporte (`creature_template.csv`, `item_template.csv`)
>
> **Alle Änderungen an diesem oder den anderen Repos müssen dort geloggt werden.**

## Project Overview

**mod-paragon** is an AzerothCore module that adds a post-level-80 Paragon progression system. When max-level players kill creatures, complete quests, or defeat bosses, they earn Paragon XP. Each Paragon level-up grants 5 stat points that can be allocated via an in-game UI. Progression is **account-wide** (level/XP shared), but point allocation is **per-character**.

The module has two point-allocation layers:
1. **C++ Aura System**: Loads stat allocations from DB on login/map-change and applies them as invisible spell auras with stacked amounts. Also handles XP gain, level-up, and config loading.
2. **Lua/AIO Paragon UI**: A client-side UI built on the AIO framework where players allocate/deallocate stat points using a currency-based system. Handles all 17 stats.

Both systems operate on the same DB table (`character_paragon_points`) and share the same aura IDs.

### Core Mechanics

- **XP Sources**: Creature kills (scaled by difficulty), daily/weekly quests (3 XP each)
- **Level-up Formula**: Each level requires `100 * 1.1^(level-1)` XP (XP counts down to 0)
- **Points per Level**: 5 points per level-up, stored as `unspent_points` in DB
- **C++ Stats (17)**: Strength, Intellect, Agility, Spirit, Stamina, Haste, Armor Pen, Spell Power, Crit, Mount Speed, Mana Regen, Hit, Block, Expertise, Parry, Dodge, Life Leech
- **Lua Stats (17)**: Same as C++ stats, all available in the Paragon UI
- **Aura System**: Stats are applied as invisible spell auras with stacked amounts
- **NPC**: Gossip-based NPC (`npc_paragon`) for info and point reset

### XP Rewards by Encounter Type

| Encounter Type        | XP  |
|-----------------------|-----|
| Regular Elite         | 1   |
| Dungeon Elite         | 1   |
| Heroic Dungeon Elite  | 2   |
| Dungeon Boss          | 3   |
| Heroic Dungeon Boss   | 5   |
| Raid Boss             | 10  |
| World Boss            | 20  |
| Daily/Weekly Quest    | 3   |

Group kills award XP to all group members in the same map.

## File Structure

```
mod-paragon/
├── conf/
│   └── mod_paragon.conf.dist                # Configuration template (currently unused by code)
├── data/sql/db-characters/base/
│   ├── character_paragon_create.sql          # Account-level paragon table
│   └── character_paragon_points_create.sql   # Character-level stat allocation table
├── Paragon_System_LUA/
│   ├── Paragon_Client.lua                    # AIO client-side UI (sent to WoW client)
│   ├── Paragon_Server.lua                    # AIO server-side handlers (allocate/deallocate)
│   └── Paragon_Data.lua                      # Data layer: stat definitions, DB access
├── src/
│   ├── Paragon_loader.cpp                    # Module entry point, script registration
│   ├── ParagonPlayer.cpp                     # Core logic: PlayerScript hooks, XP, auras
│   ├── ParagonNPC.cpp                        # NPC gossip for info/reset
│   └── ParagonUtils.h                        # Header with function declarations
└── apps/ci/ci-codestyle.sh                   # CI codestyle validation
```

## Lua/AIO System Architecture

The Lua code implements a paragon stat allocation UI using the [AIO (AddOn IO) framework](https://github.com/Rochet2/AIO) for Eluna. AIO enables server-to-client Lua communication, allowing server-side Lua scripts to create and control client-side WoW addon UI frames.

### How AIO Works

- **Server scripts** (`Paragon_Server.lua`, `Paragon_Data.lua`) run on the Eluna Lua engine inside the worldserver
- **Client script** (`Paragon_Client.lua`) is sent to the WoW client as an addon via AIO on login
- Communication uses `AIO.Handle(player, "HANDLER_NAME", "Method", args...)` (server->client) and `AIO.Handle("HANDLER_NAME", "Method", args...)` (client->server)
- Handler registration: `AIO.AddHandlers("HANDLER_NAME", {})` creates a handler table on both sides
- **IMPORTANT**: `AddHandlers` wraps all handler functions with `function(player, key, ...) handlertable[key](player, ...) end`. This means handler functions on BOTH server AND client always receive `player` as their first argument. On the client side, `player` is a string identifier, not a WoW player object — it must still be declared as a parameter to keep argument positions correct.
- Handler names: `PARAGON_SERVER` (server-side), `PARAGON_CLIENT` (client-side)

### Paragon_Data.lua — Data Layer

Defines all stat categories, stat definitions (17 stats), and DB access functions.

**`Paragon.MAX_POINTS`**: Configurable table of per-stat max points (default 255 each). Must match `Paragon.Max*` values in `mod_paragon.conf`.

**`Paragon.GetAllocations(characterID)`**: Queries `character_paragon_points` from the characters DB to fetch stat allocations. Returns a table indexed by stat ID.

**Sound effects**: Contains race/gender-specific sound IDs for "not enough money" voice feedback.

### Paragon_Server.lua — Server Logic

**Handler registration**: `AIO.AddHandlers("PARAGON_SERVER", {})` — the client calls these methods via AIO.

**Server methods**:

| Method             | Description                                                |
|--------------------|------------------------------------------------------------|
| `RequestData`      | Sends categories, stats, allocations and points to client  |
| `AllocatePoint`    | Spend currency to add stat points (supports bulk via Shift)|
| `DeallocatePoint`  | Remove stat points and refund currency                     |

### Paragon_Client.lua — Client UI

A WoW addon UI built using WoW's frame API, sent to clients via AIO:

**UI Components**:
- **Main Frame** (`ParagonFrame`): 620x440 movable frame, centered on screen
- **Category Tabs**: Left sidebar with category buttons (Primary, Offensive, Defensive, Utility)
- **Stat Rows**: Up to 8 rows showing stat icon, name, tooltip, current/max points, +/- buttons
- **Allocate/Deallocate Buttons**: Per-stat "+"/"-" buttons (Shift+Click for 10 at once)

**Point display**: Each stat row shows current allocation as "X/MAX" where MAX comes from `stat.maxPoints` (configurable via `Paragon.MAX_POINTS`).

**Game menu integration**: Adds a "Paragon" button to the ESC menu (`GameMenuFrame`).

## Database Schema (characters DB)

### `character_paragon` — Account-wide progression

| Column      | Type              | Description                |
|-------------|-------------------|----------------------------|
| `accountID` | INT UNSIGNED (PK) | Account ID                 |
| `level`     | INT               | Current Paragon level      |
| `xp`        | INT               | XP remaining until level-up (counts DOWN) |

### `character_paragon_points` — Per-character stat allocation

| Column          | Type     | Description                    |
|-----------------|----------|--------------------------------|
| `characterID`   | INT (PK) | Character GUID                 |
| `unspent_points`| INT      | Available unallocated points   |
| `pstrength`     | INT      | Points in Strength             |
| `pintellect`    | INT      | Points in Intellect            |
| `pagility`      | INT      | Points in Agility              |
| `pspirit`       | INT      | Points in Spirit               |
| `pstamina`      | INT      | Points in Stamina              |

The SQL schema defines `unspent_points` plus all 17 stat columns matching the C++ code: `pstrength`, `pintellect`, `pagility`, `pspirit`, `pstamina`, `phaste`, `parmpen`, `pspellpower`, `pcrit`, `pmspeed`, `pmreg`, `phit`, `pblock`, `pexpertise`, `pparry`, `pdodge`, `plifeleech`.

## Custom Game Data Dependencies

These must exist in the game database/client for the module to function:

- **Spell/Aura IDs (C++ and Lua, unified)**: 100000 (level counter), 100001-100005 (Str, Int, Agi, Spi, Sta), 100016-100026 (Haste through Dodge)
- **All Aura IDs are configurable** via `mod_paragon.conf` (Paragon.IdStr, Paragon.IdInt, etc.)
- **Unspent Points**: Stored in `character_paragon_points.unspent_points` (DB-based, no item)
- **Gossip Text ID**: 197760 (NPC greeting text, must exist in `npc_text`)
- **NPC Script Name**: `npc_paragon` (must be assigned to a creature via `creature_template.ScriptName`)

## Build & Integration

- Standard AzerothCore module: place/symlink into `modules/` directory
- No custom `CMakeLists.txt` needed (uses AzerothCore module auto-detection)
- Entry point: `Addmod_paragonScripts()` in `Paragon_loader.cpp`
- **Lua files** are in `Paragon_System_LUA/` and must be placed in the Eluna scripts directory
- **AIO dependency**: The Lua system requires [AIO by Rochet2](https://github.com/Rochet2/AIO) installed on the server

## Code Style

Follow the AzerothCore C++ and SQL code standards (see parent repo CLAUDE.md):
- 4-space indentation, no tabs
- UTF-8 encoding, LF line endings
- Max 80 character line length
- `auto const&` (not `const auto&`), `Type const*` (not `const Type*`)
- Use prepared statements for DB queries (not string formatting)
- Backtick table/column names in SQL

Lua code uses tab indentation and follows standard Eluna API conventions.

## Known Issues and Improvement Opportunities

### Critical Bugs (all fixed)

1. ~~**Schema Mismatch**~~: FIXED — SQL now has all 16 stat columns.
2. ~~**NPC Script Not Registered**~~: FIXED — `AddMyNPCScripts()` called in loader.
3. ~~**Incomplete Point Reset**~~: FIXED — All 16 stats reset via prepared statement.
4. ~~**Parameter Order Bug**~~: FIXED — Refactored to array-based `RefreshParagonAura()`, no more parameter ordering issues.

### Security Issues

5. ~~**No Prepared Statements (C++)**~~: FIXED — All queries use `CharacterDatabasePreparedStatement`.
6. **SQL Injection in Lua** (`Paragon_Server.lua`): `CharDBExecute` calls use string concatenation with player data. Eluna's DB API doesn't support prepared statements, but values should be validated/sanitized.

### Functional Gaps

7. ~~**Configuration Never Used**~~: FIXED — `ParagonConfig::OnAfterConfigLoad` reads 30+ options from `mod_paragon.conf`.
8. **Empty Gossip Case** (`ParagonNPC.cpp:34-36`): Case 1 ("How does Abyssal Mastery work?") has no implementation.
9. ~~**Eluna Declaration Without Implementation**~~: FIXED — Removed from `ParagonUtils.h`.
10. ~~**Forced Logout on Reset**~~: FIXED — Reset now reapplies auras via `ApplyParagonStatEffects()` instead of forcing logout.
11. ~~**Health/Mana Exploit**~~: FIXED — `RefreshParagonAura()` no longer restores HP/mana.
12. ~~**C++ and Lua Use Different Aura IDs for Strength**~~: FIXED — Both now use `100001`.

### Code Quality (all fixed)

14. ~~**Massive Code Duplication**~~: FIXED — Data-driven loop with `conf_AuraIds[16]`.
15. ~~**Unused Variables**~~: FIXED — `bool debug` removed.
16. ~~**`Query()` for INSERT/UPDATE**~~: FIXED — All write operations use `.Execute()`.
17. ~~**XP Overflow Risk**~~: FIXED — Proper `int64` arithmetic with cap.
18. ~~**Duplicated Login/MapChange Logic**~~: FIXED — MapChange reads from in-memory cache via `RestoreFromCache()`.
19. ~~**`GetRawValue()` Truncation**~~: FIXED — Uses `GetCounter()` consistently.

### Potential Enhancements

- **Unify C++ and Lua Systems**: Decide on one point-allocation mechanism. Currently both can modify the same DB table with incompatible logic
- ~~**In-Memory Caching**~~: DONE — Account-level cache with mutex protection
- ~~**Configurable System**~~: DONE — All values read from `mod_paragon.conf`
- **Anti-Farm Measures**: Cooldown or diminishing returns on XP from repeated kills
- ~~**Max Level Cap**~~: DONE — `Paragon.MaxLevel` config option (0 = no limit)
