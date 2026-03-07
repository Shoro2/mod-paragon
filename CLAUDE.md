# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mod-paragon** is an AzerothCore module that adds a post-level-80 Paragon progression system. When max-level players kill creatures, complete quests, or defeat bosses, they earn Paragon XP. Each Paragon level-up grants 5 stat points that can be allocated via an in-game UI. Progression is **account-wide** (level/XP shared), but point allocation is **per-character**.

The module has two independent point-allocation interfaces:
1. **C++ Aura System** (16 stats): Points are allocated via an unspecified mechanism and applied as invisible spell auras with stacked amounts
2. **Lua/AIO Paragon UI** (5 stats): A client-side UI built on the AIO framework where players allocate/deallocate stat points using a currency-based system

These two systems are **not integrated** — they operate on the same DB table but with different stat sets and different logic.

### Core Mechanics

- **XP Sources**: Creature kills (scaled by difficulty), daily/weekly quests (3 XP each)
- **Level-up Formula**: Each level requires `100 * 1.1^(level-1)` XP (XP counts down to 0)
- **Points per Level**: 5 points per level-up, delivered as item `920920` ("unspent points")
- **C++ Stats (16)**: Strength, Intellect, Agility, Spirit, Stamina, Haste, Armor Pen, Spell Power, Crit, Mount Speed, Mana Regen, Hit, Block, Expertise, Parry, Dodge
- **Lua Stats (5)**: Strength, Intellect, Agility, Spirit, Stamina (mapped to aura IDs 100001-100005)
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
│   ├── Paragon_Client.lua                    # AIO client-side UI for stat allocation
│   ├── Paragon_Server.lua                    # AIO server-side handlers (allocate/deallocate)
│   └── Paragon_DataStruct.lua               # Data structures, DB loading, sound effects
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

- **Server scripts** (`Paragon_Server.lua`, `Paragon_DataStruct.lua`) run on the Eluna Lua engine inside the worldserver
- **Client script** (`Paragon_Client.lua`) is sent to the WoW client as an addon via AIO on login
- Communication uses `AIO.Handle(player, "HANDLER_NAME", "Method", args...)` (server->client) and `AIO.Handle("HANDLER_NAME", "Method", args...)` (client->server)
- Handler registration: `AIO.AddHandlers("HANDLER_NAME", {})` creates a handler table on both sides
- **IMPORTANT**: `AddHandlers` wraps all handler functions with `function(player, key, ...) handlertable[key](player, ...) end`. This means handler functions on BOTH server AND client always receive `player` as their first argument. On the client side, `player` is a string identifier, not a WoW player object — it must still be declared as a parameter to keep argument positions correct.
- Handler names: `PARAGON_SERVER` (server-side), `PARAGON_CLIENT` (client-side)

### Paragon_DataStruct.lua — Data Layer

Loads and caches data from a **separate `store` database schema** (not the characters DB):

| Table                          | Description                    |
|--------------------------------|--------------------------------|
| `store.store_categories`       | Navigation categories          |
| `store.store_currencies`       | Currency definitions           |
| `store.store_services`         | Stat services (paragon stats)  |
| `store.store_category_service_link` | Links services to categories |

**Data keys** are defined as numeric indices in the `KEYS` table (not named fields), matching SQL column order.

**`GetParagonData(characterID)`**: Queries `character_paragon_points` from the characters DB using explicit column SELECT (not `SELECT *`) to fetch stat allocations. Returns a table indexed 1-5 for strength, intellect, agility, spirit, stamina.

**Sound effects**: Contains race/gender-specific sound IDs for "not enough money" voice feedback.

### Paragon_Server.lua — Server Logic

**Handler registration**: `AIO.AddHandlers("PARAGON_SERVER", {})` — the client calls these methods via AIO.

**Server methods**:

| Method             | Description                                      |
|--------------------|--------------------------------------------------|
| `FrameData`        | Sends all service/category/currency/paragon data |
| `UpdateCurrencies` | Refreshes currency values and paragon data       |
| `AllocatePoint`    | Spend currency to add 1 stat point               |
| `DeallocatePoint`  | Remove 1 stat point and refund currency          |

**Aura-to-column mapping** (`AURA_COLUMN_MAP`):
- 100001 -> pstrength
- 100002 -> pintellect
- 100003 -> pagility
- 100004 -> pspirit
- 100005 -> pstamina

**Currency types**: `GOLD` (player coinage), `ITEM_TOKEN` (item count), `SERVER_HANDLED` (custom, unimplemented).

**Currency helpers**: `DeductCurrency()` and `AddCurrency()` are module-level functions handling gold/token/custom currency operations.

### Paragon_Client.lua — Client UI

A WoW addon UI built using WoW's frame API, sent to clients via AIO:

**UI Components**:
- **Main Frame** (`PARAGON_FRAME`): 1024x658 textured frame, anchored left of screen
- **Navigation Buttons**: Up to 11 category tabs on the left sidebar
- **Service Boxes**: 8 per page (4x2 grid) showing stat allocation with icons, names, costs, current points
- **Pagination**: Back/forward buttons for multi-page categories
- **Currency Badges**: Up to 4 currency displays at bottom-left
- **Allocate/Deallocate Buttons**: Per-stat "+"/"-" buttons

**Point display**: Each service box shows current allocation as "X/255" using paragon data received from server. Uses `AURA_TO_PARAGON_INDEX` to map aura IDs to data indices.

**Access control**: Categories can require a minimum GM rank (`requiredRank` field).

**Game menu integration**: Adds a "Paragon" button to the ESC menu (`GameMenuFrame`).

## Database Schema (characters DB)

### `character_paragon` — Account-wide progression

| Column      | Type              | Description                |
|-------------|-------------------|----------------------------|
| `accountID` | INT UNSIGNED (PK) | Account ID                 |
| `level`     | INT               | Current Paragon level      |
| `xp`        | INT               | XP remaining until level-up (counts DOWN) |

### `character_paragon_points` — Per-character stat allocation

| Column        | Type     | Description             |
|---------------|----------|-------------------------|
| `characterID` | INT (PK) | Character GUID          |
| `pstrength`   | INT      | Points in Strength      |
| `pintellect`  | INT      | Points in Intellect     |
| `pagility`    | INT      | Points in Agility       |
| `pspirit`     | INT      | Points in Spirit        |
| `pstamina`    | INT      | Points in Stamina       |

**CRITICAL**: The SQL schema only defines 5 stat columns, but the C++ code reads 16 columns (indices 1-16). The missing columns are: `phaste`, `parmpen`, `pspellpower`, `pcrit`, `pmspeed`, `pmreg`, `phit`, `pblock`, `pexpertise`, `pparry`, `pdodge`. The SQL must be updated to match the C++ code.

### `store.*` — External store database (Lua system)

The Lua system requires a separate `store` database schema with these tables:

| Table                          | Key Columns                                  |
|--------------------------------|----------------------------------------------|
| `store.store_categories`       | id, name, icon, requiredRank, flags, enabled |
| `store.store_currencies`       | id, type, name, icon, data, tooltip          |
| `store.store_services`         | id, serviceType, name, tooltipName, tooltipType, tooltipText, icon, price, currency, hyperlink, displayOrEntry, discount, flags, reward_1..8, rewardCount_1..8, new, enabled |
| `store.store_category_service_link` | categoryId, serviceId                   |

**NOTE**: No SQL files for these tables exist in the repository. They must be created manually or obtained from the store system's original source.

## Custom Game Data Dependencies

These must exist in the game database/client for the module to function:

- **Spell/Aura IDs (C++)**: 100000 (level counter), 7507 (strength), 100002-100005, 100016-100026
- **Spell/Aura IDs (Lua)**: 100001-100005 (strength, intellect, agility, spirit, stamina — used by AllocatePoint/DeallocatePoint)
- **Item ID**: 920920 (unspent paragon points token)
- **Gossip Text ID**: 197760 (NPC greeting text, must exist in `npc_text`)
- **NPC Script Name**: `npc_paragon` (must be assigned to a creature via `creature_template.ScriptName`)
- **Client Textures**: `Interface/Store_UI/Frames/StoreFrame_Main` and `Interface/Store_UI/Currencies/*` (custom MPQ/patch required)

## Build & Integration

- Standard AzerothCore module: place/symlink into `modules/` directory
- No custom `CMakeLists.txt` needed (uses AzerothCore module auto-detection)
- Entry point: `Addmod_paragonScripts()` in `Paragon_loader.cpp`
- **Lua files** must be placed in the Eluna script directory (not auto-loaded by the C++ module system)
- **AIO dependency**: The Lua system requires [AIO by Rochet2](https://github.com/Rochet2/AIO) installed on the server
- **Client patch**: Custom UI textures must be delivered via an MPQ patch to WoW clients

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

### Critical Bugs

1. **Schema Mismatch** (`character_paragon_points_create.sql` vs `ParagonPlayer.cpp:116-131`): SQL defines 5 stat columns, code reads 16. INSERTs specify 17 columns. All queries against this table will fail at runtime.

2. **NPC Script Not Registered** (`Paragon_loader.cpp:13`): `AddMyNPCScripts()` is never called in the loader. The Paragon NPC gossip is completely non-functional.

3. **Incomplete Point Reset** (`ParagonNPC.cpp:53`): `ResetParagonPoints()` only resets 5 of 16 stats to 0. The other 11 stats remain allocated after a "reset".

4. **Parameter Order Bug** (`ParagonPlayer.cpp:144`): `RefreshParagonAura()` call swaps `pdodge` and `pparry` argument order vs the function signature (line 43), causing these two stats to be applied to the wrong auras.

### Security Issues

5. **No Prepared Statements (C++)**: All DB queries use string-formatted `.Query()` / `.Execute()` calls. Should use `CharacterDatabasePreparedStatement`.

6. **SQL Injection in Lua** (`Paragon_Server.lua`): `CharDBExecute` calls use string concatenation with player data. Eluna's DB API doesn't support prepared statements, but values should be validated/sanitized.

### Functional Gaps

7. **Configuration Never Used**: `mod_paragon.conf.dist` defines Enable, spell IDs, XP values, PPL, and party reduction — but the code hardcodes all values and never calls `sConfigMgr->GetOption<>()`.

8. **Empty Gossip Case** (`ParagonNPC.cpp:34-36`): Case 1 ("How does Abyssal Mastery work?") has no implementation.

9. **Eluna Declaration Without Implementation** (`ParagonUtils.h:10`): `RegisterParagonEluna(lua_State* L)` declared but never defined. Will cause linker errors if called.

10. **Forced Logout on Reset** (`ParagonNPC.cpp:54`): `LogoutPlayer(true)` after resetting points. Poor UX — should reapply auras instead.

11. **Health/Mana Exploit** (`ParagonPlayer.cpp:100-104`): `RefreshParagonAura()` fully restores HP/mana outside dungeons/raids on every aura refresh (login, map change).

12. **Missing Store Schema**: No SQL files exist for the `store.*` tables required by the Lua system. Server admins must create these manually.

13. **C++ and Lua Use Different Aura IDs for Strength**: C++ uses aura `7507` for strength, Lua uses `100001`. These will conflict if both systems are active simultaneously.

### Code Quality

14. **Massive Code Duplication in C++** (`ParagonPlayer.cpp:45-96`): 16 identical `RemoveAura` + `if > 0 AddAura/SetAuraStack` blocks. Should use a data-driven loop.

15. **Unused Variables**: `bool debug = true` (C++) is never referenced.

16. **`Query()` for INSERT/UPDATE** (`ParagonPlayer.cpp`): Uses `CharacterDatabase.Query()` for write operations. Should use `.Execute()`.

17. **XP Overflow Risk** (`ParagonPlayer.cpp:349`): `pow(1.1, paragonLevel - 1)` overflows `uint32` at high levels. The `newXP < 0` check is dead code (uint32 is always >= 0).

18. **Duplicated Login/MapChange Logic** (`ParagonPlayer.cpp:155-202`): Nearly identical DB query + aura application logic.

19. **`GetRawValue()` Truncation** (`ParagonPlayer.cpp:112,135`): `ObjectGuid::GetRawValue()` returns `uint64`, stored in `uint32`. Should use `GetCounter()`.

### Potential Enhancements

- **Unify C++ and Lua Systems**: Decide on one point-allocation mechanism. Currently both can modify the same DB table with incompatible logic
- **In-Memory Caching**: Cache paragon level/points in player data to avoid DB queries on every map change
- **Configurable System**: Read from `mod_paragon.conf.dist` to allow tuning XP rates, points per level, enable/disable
- **Anti-Farm Measures**: Cooldown or diminishing returns on XP from repeated kills
- **Store Schema SQL Files**: Add creation scripts for `store.*` tables
- **Max Level Cap**: No upper bound on Paragon level — may need a configurable cap
