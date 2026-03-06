# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mod-paragon** is an AzerothCore module that adds a post-level-80 Paragon progression system. When max-level players kill creatures, complete quests, or defeat bosses, they earn Paragon XP. Each Paragon level-up grants 5 stat points that can be allocated via an in-game UI. Progression is **account-wide** (level/XP shared), but point allocation is **per-character**.

The module has two independent point-allocation interfaces:
1. **C++ Aura System** (16 stats): Points are allocated via an unspecified mechanism and applied as invisible spell auras with stacked amounts
2. **Lua/AIO Shop UI** (5 stats only): A client-side UI built on the AIO framework where players buy/sell stat points using a currency-based store system

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
│   ├── Store_Client.lua                      # AIO client-side UI (1256 lines)
│   ├── Store_Server.lua                      # AIO server-side handlers (544 lines)
│   └── Store_DataStruct.lua                  # Shared data structures & DB loading (406 lines)
├── src/
│   ├── Paragon_loader.cpp                    # Module entry point, script registration
│   ├── ParagonPlayer.cpp                     # Core logic: PlayerScript hooks, XP, auras
│   ├── ParagonNPC.cpp                        # NPC gossip for info/reset
│   └── ParagonUtils.h                        # Header with function declarations
└── apps/ci/ci-codestyle.sh                   # CI codestyle validation
```

## Lua/AIO System Architecture

The Lua code implements a complete in-game store UI using the [AIO (AddOn IO) framework](https://github.com/Rochet2/AIO) for Eluna. AIO enables server-to-client Lua communication, allowing server-side Lua scripts to create and control client-side WoW addon UI frames.

### How AIO Works

- **Server scripts** (`Store_Server.lua`, `Store_DataStruct.lua`) run on the Eluna Lua engine inside the worldserver
- **Client script** (`Store_Client.lua`) is sent to the WoW client as an addon via AIO on login
- Communication uses `AIO.Handle(player, "HANDLER_NAME", "Method", args...)` (server→client) and `AIO.Handle("HANDLER_NAME", "Method", args...)` (client→server)
- Handler registration: `AIO.AddHandlers("HANDLER_NAME", {})` creates a handler table on both sides

### Store_DataStruct.lua — Data Layer

Loads and caches all store data from a **separate `store` database schema** (not the characters DB):

| Table                          | Description                    |
|--------------------------------|--------------------------------|
| `store.store_categories`       | Navigation categories          |
| `store.store_currencies`       | Currency definitions           |
| `store.store_services`         | Purchasable services/items     |
| `store.store_category_service_link` | Links services to categories |
| `store.store_logs`             | Purchase audit log             |

Also queries `creature_template` from the world DB for mount/pet model previews.

**Data keys** are defined as numeric indices in the `KEYS` table (not named fields), matching SQL column order.

**Paragon-specific function**: `GetParagonData(characterID)` queries `character_paragon_points` from the characters DB to fetch stat allocations.

**Critical bug in GetParagonData** (`Store_DataStruct.lua:211-222`): The function reads columns incorrectly — indices 2-4 are all read as `GetString(2)`, meaning intellect, agility, spirit, and stamina all return the same value (the intellect column). Should be:
```lua
Query:GetUInt32(1), -- strength
Query:GetUInt32(2), -- intellect
Query:GetUInt32(3), -- agility
Query:GetUInt32(4), -- spirit
Query:GetUInt32(5), -- stamina
```

### Store_Server.lua — Server Logic

**Handler registration**: `AIO.AddHandlers("STORE_SERVER", {})` — the client calls these methods via AIO.

**Service types** (mapped via `SHOP_UI.serviceHandlers`):

| Type ID | Handler          | Description                    |
|---------|------------------|--------------------------------|
| 1       | ItemHandler      | Mail items to player           |
| 2       | GoldHandler      | Add gold                       |
| 3       | MountHandler     | Teach mount spells             |
| 4       | PetHandler       | Teach pet spells               |
| 5       | BuffHandler      | Cast buff spells               |
| 6       | UnusedHandler    | Placeholder (always fails)     |
| 7       | ServiceHandler   | Set AtLogin flags              |
| 8       | LevelHandler     | Set/add player level           |
| 9       | TitleHandler     | Grant titles                   |
| 10      | ParagonPlus      | Add 1 paragon stat point       |
| 11      | ParagonMinus     | Remove 1 paragon stat point    |

**Currency types**: `GOLD` (player coinage), `ITEM_TOKEN` (item count), `SERVER_HANDLED` (custom, unimplemented).

**ParagonPlus** (`Store_Server.lua:445-483`): Deducts currency, adds/increments an aura stack, and updates `character_paragon_points` via `CharDBExecute`. Maps aura IDs to stat columns:
- 100001 → pstrength
- 100002 → pintellect
- 100003 → pagility
- 100004 → pspirit
- 100005 → pstamina

**ParagonMinus** (`Store_Server.lua:487-535`): Checks for existing aura, refunds currency, decrements aura stack, and decrements the DB value.

**Security issues in Lua**:
- All DB queries use string concatenation (`"... WHERE accoundID = "..accoundID`), vulnerable to SQL injection
- The column name `accoundID` is a typo — should be `characterID` or `accountID` depending on intent. The C++ code uses `characterID` as the primary key, but the Lua code passes `player:GetAccountId()` and queries against `accoundID` (which doesn't exist in the schema)
- `WorldDBExecute` for purchase logging writes to `store.store_logs` — this schema must exist separately

### Store_Client.lua — Client UI

A complete WoW addon UI built using WoW's frame API, sent to clients via AIO:

**UI Components**:
- **Main Frame** (`SHOP_FRAME`): 1024x658 textured frame, anchored left of screen
- **Navigation Buttons**: Up to 11 category tabs on the left sidebar
- **Service Boxes**: 8 per page (4x2 grid) showing purchasable items with icons, names, prices
- **Pagination**: Back/forward buttons for multi-page categories
- **Currency Badges**: Up to 4 currency displays at bottom-left
- **Model Preview**: 3D model viewer for mounts/pets/items (DressUpModel + PlayerModel frames)
- **Buy/Sell Buttons**: Per-service "+"/"-" buttons for paragon point allocation

**Access control**: Categories can require a minimum GM rank (`requiredRank` field).

**Special category flags**: Flag 1 = auto-populate discounted items; Flag 2 = auto-populate "new" items.

**Game menu integration**: Adds a "Paragon" button to the ESC menu (`GameMenuFrame`).

**Paragon UI elements**: Each service box has a `ParagonDisplay` font string showing "0/255" and buy/sell buttons. The sell button sends `serviceId * 10` to differentiate from purchase (handled by `StoreHandler.Sell`).

**Incomplete function**: `SHOP_UI.ParagonDataUpdate()` (`Store_Client.lua:924-931`) is broken — references undefined `Services` variable, `GetServiceData(i)` is called with wrong signature. The `UpdateParagon` handler is commented out in both client and server.

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
| `store.store_logs`             | account, guid, serviceId, currencyId, cost   |

**NOTE**: No SQL files for these tables exist in the repository. They must be created manually or obtained from the store system's original source.

## Custom Game Data Dependencies

These must exist in the game database/client for the module to function:

- **Spell/Aura IDs (C++)**: 100000 (level counter), 7507 (strength), 100002-100005, 100016-100026
- **Spell/Aura IDs (Lua)**: 100001-100005 (strength, intellect, agility, spirit, stamina — used by ParagonPlus/Minus)
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

5. **GetParagonData Wrong Column Indices** (`Store_DataStruct.lua:211-222`): All stat columns read `GetString(2)` instead of incrementing indices. Returns intellect value for all 5 stats. Also uses `GetString` instead of `GetUInt32` for numeric fields.

6. **Lua Queries Wrong Key Column** (`Store_Server.lua:468-481`): ParagonPlus/Minus use `WHERE accoundID = <accountId>` but the `character_paragon_points` table uses `characterID` (character GUID) as primary key, not account ID. Column name is also misspelled (`accoundID`).

7. **ParagonDataUpdate Broken** (`Store_Client.lua:924-931`): References undefined `Services` variable, calls `GetServiceData(i)` with wrong signature (expects table of IDs, receives single int). Paragon point display on client is non-functional.

### Security Issues

8. **No Prepared Statements (C++)**: All DB queries use string-formatted `.Query()` / `.Execute()` calls. Should use `CharacterDatabasePreparedStatement`.

9. **SQL Injection in Lua** (`Store_Server.lua:222,468-531`): All `CharDBExecute` and `WorldDBExecute` calls use string concatenation with player data. Eluna's DB API doesn't support prepared statements, but values should be validated/sanitized.

### Functional Gaps

10. **Configuration Never Used**: `mod_paragon.conf.dist` defines Enable, spell IDs, XP values, PPL, and party reduction — but the code hardcodes all values and never calls `sConfigMgr->GetOption<>()`.

11. **Empty Gossip Case** (`ParagonNPC.cpp:34-36`): Case 1 ("How does Abyssal Mastery work?") has no implementation.

12. **Eluna Declaration Without Implementation** (`ParagonUtils.h:10`): `RegisterParagonEluna(lua_State* L)` declared but never defined. Will cause linker errors if called.

13. **Forced Logout on Reset** (`ParagonNPC.cpp:54`): `LogoutPlayer(true)` after resetting points. Poor UX — should reapply auras instead.

14. **Health/Mana Exploit** (`ParagonPlayer.cpp:100-104`): `RefreshParagonAura()` fully restores HP/mana outside dungeons/raids on every aura refresh (login, map change).

15. **UpdateParagon Disabled**: The `StoreHandler.UpdateParagon` handler is commented out in both `Store_Client.lua:107-109` and `Store_Server.lua:96`. Paragon point display never updates on the client after allocation.

16. **Missing Store Schema**: No SQL files exist for the `store.*` tables required by the Lua system. Server admins must create these manually.

17. **C++ and Lua Use Different Aura IDs for Strength**: C++ uses aura `7507` for strength, Lua uses `100001`. These will conflict if both systems are active simultaneously.

### Code Quality

18. **Massive Code Duplication in C++** (`ParagonPlayer.cpp:45-96`): 16 identical `RemoveAura` + `if > 0 AddAura/SetAuraStack` blocks. Should use a data-driven loop.

19. **Massive Code Duplication in Lua** (`Store_Server.lua:467-531`): ParagonPlus and ParagonMinus each have 5 identical if-blocks mapping aura IDs to column names. Should use a lookup table.

20. **Unused Variables**: `bool debug = true` (C++) is never referenced.

21. **`Query()` for INSERT/UPDATE** (`ParagonPlayer.cpp`): Uses `CharacterDatabase.Query()` for write operations. Should use `.Execute()`.

22. **XP Overflow Risk** (`ParagonPlayer.cpp:349`): `pow(1.1, paragonLevel - 1)` overflows `uint32` at high levels. The `newXP < 0` check is dead code (uint32 is always >= 0).

23. **Duplicated Login/MapChange Logic** (`ParagonPlayer.cpp:155-202`): Nearly identical DB query + aura application logic.

24. **`GetRawValue()` Truncation** (`ParagonPlayer.cpp:112,135`): `ObjectGuid::GetRawValue()` returns `uint64`, stored in `uint32`. Should use `GetCounter()`.

25. **ParagonMinus Stack Bug** (`Store_Server.lua:510-514`): When stack count is exactly 1, it decrements to 0 via `SetStackAmount(0)` instead of removing the aura. The `stacks >= 1` check should be `stacks > 1` for the decrement path.

### Potential Enhancements

- **Unify C++ and Lua Systems**: Decide on one point-allocation mechanism. Currently both can modify the same DB table with incompatible logic
- **In-Memory Caching**: Cache paragon level/points in player data to avoid DB queries on every map change
- **Configurable System**: Read from `mod_paragon.conf.dist` to allow tuning XP rates, points per level, enable/disable
- **Anti-Farm Measures**: Cooldown or diminishing returns on XP from repeated kills
- **Fix Client Paragon Display**: Implement working `UpdateParagon` handler so the UI shows current point allocation
- **Store Schema SQL Files**: Add creation scripts for `store.*` tables
- **Max Level Cap**: No upper bound on Paragon level — may need a configurable cap
