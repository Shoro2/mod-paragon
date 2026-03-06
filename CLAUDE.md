# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mod-paragon** (aka "Abyssal Mastery") is an AzerothCore module that adds a post-level-80 Paragon progression system. When max-level players kill creatures, complete quests, or defeat bosses, they earn Paragon XP. Each Paragon level-up grants 5 stat points that can be allocated across 16 different stats. Progression is **account-wide** (level/XP shared), but point allocation is **per-character**.

### Core Mechanics

- **XP Sources**: Creature kills (scaled by difficulty), daily/weekly quests (3 XP each)
- **Level-up Formula**: Each level requires `100 * 1.1^(level-1)` XP (XP counts down to 0)
- **Points per Level**: 5 points per level-up, delivered as item `920920` ("unspent points")
- **Stats**: Strength, Intellect, Agility, Spirit, Stamina, Haste, Armor Pen, Spell Power, Crit, Mount Speed, Mana Regen, Hit, Block, Expertise, Parry, Dodge
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
│   └── mod_paragon.conf.dist        # Configuration template (currently unused by code)
├── data/sql/db-characters/base/
│   ├── character_paragon_create.sql         # Account-level paragon table
│   └── character_paragon_points_create.sql  # Character-level stat allocation table
├── src/
│   ├── Paragon_loader.cpp           # Module entry point, script registration
│   ├── ParagonPlayer.cpp            # Core logic: PlayerScript hooks, XP, auras (385 lines)
│   ├── ParagonNPC.cpp               # NPC gossip for info/reset (62 lines)
│   └── ParagonUtils.h               # Header with function declarations
└── apps/ci/ci-codestyle.sh          # CI codestyle validation
```

## Database Schema (characters DB)

### `character_paragon` - Account-wide progression

| Column      | Type              | Description                |
|-------------|-------------------|----------------------------|
| `accountID` | INT UNSIGNED (PK) | Account ID                 |
| `level`     | INT               | Current Paragon level      |
| `xp`        | INT               | XP remaining until level-up (counts DOWN) |

### `character_paragon_points` - Per-character stat allocation

| Column        | Type     | Description             |
|---------------|----------|-------------------------|
| `characterID` | INT (PK) | Character GUID          |
| `pstrength`   | INT      | Points in Strength      |
| `pintellect`  | INT      | Points in Intellect     |
| `pagility`    | INT      | Points in Agility       |
| `pspirit`     | INT      | Points in Spirit        |
| `pstamina`    | INT      | Points in Stamina       |

**CRITICAL**: The SQL schema only defines 5 stat columns, but the C++ code reads 16 columns (indices 1-16). The missing columns are: `phaste`, `parmpen`, `pspellpower`, `pcrit`, `pmspeed`, `pmreg`, `phit`, `pblock`, `pexpertise`, `pparry`, `pdodge`. The SQL must be updated to match the code.

## Custom Game Data Dependencies

These must exist in the game database/client for the module to function:

- **Spell/Aura IDs**: 100000 (level counter), 7507 (strength), 100002-100005, 100016-100026
- **Item ID**: 920920 (unspent paragon points token)
- **Gossip Text ID**: 197760 (NPC greeting text, must exist in `npc_text`)
- **NPC Script Name**: `npc_paragon` (must be assigned to a creature via `creature_template.ScriptName`)

## Build & Integration

- Standard AzerothCore module: place/symlink into `modules/` directory
- No custom `CMakeLists.txt` needed (uses AzerothCore module auto-detection)
- Requires Eluna/Lua headers at compile time (included but functionality unused)
- Entry point: `Addmod_paragonScripts()` in `Paragon_loader.cpp`

## Code Style

Follow the AzerothCore C++ and SQL code standards (see parent repo CLAUDE.md):
- 4-space indentation, no tabs
- UTF-8 encoding, LF line endings
- Max 80 character line length
- `auto const&` (not `const auto&`), `Type const*` (not `const Type*`)
- Use prepared statements for DB queries (not string formatting)
- Backtick table/column names in SQL

## Known Issues and Improvement Opportunities

### Critical Bugs

1. **Schema Mismatch** (`character_paragon_points_create.sql` vs `ParagonPlayer.cpp:116-131`): SQL defines 5 stat columns, code reads 16. INSERTs specify 17 columns. All queries against this table will fail at runtime.

2. **NPC Script Not Registered** (`Paragon_loader.cpp:13`): `AddMyNPCScripts()` is never called in the loader. The Paragon NPC gossip is completely non-functional.

3. **Incomplete Point Reset** (`ParagonNPC.cpp:53`): `ResetParagonPoints()` only resets 5 of 16 stats to 0. The other 11 stats remain allocated after a "reset".

4. **Parameter Order Bug** (`ParagonPlayer.cpp:144`): `RefreshParagonAura()` call swaps `pdodge` and `pparry` argument order vs the function signature (line 43), causing these two stats to be applied to the wrong auras.

### Security Issues

5. **No Prepared Statements**: All DB queries use string-formatted `.Query()` / `.Execute()` calls (e.g., `ParagonPlayer.cpp:112,138,159,164,167,176,337,356,366`; `ParagonNPC.cpp:53`). AzerothCore standard requires prepared statements. While the current format string API may handle escaping, these should be migrated to `CharacterDatabasePreparedStatement` for safety and performance.

### Functional Gaps

6. **Configuration Never Used**: `mod_paragon.conf.dist` defines Enable, spell IDs, XP values, PPL, and party reduction — but the code hardcodes all values and never calls `sConfigMgr->GetOption<>()`.

7. **Empty Gossip Case** (`ParagonNPC.cpp:34-36`): Case 1 ("How does Abyssal Mastery work?") has no implementation — does nothing on click.

8. **Eluna Declaration Without Implementation** (`ParagonUtils.h:10`): `RegisterParagonEluna(lua_State* L)` is declared but has no implementation anywhere. Will cause linker errors if any code calls it.

9. **Forced Logout on Reset** (`ParagonNPC.cpp:54`): `LogoutPlayer(true)` is called after resetting points. This is a poor UX — should reapply auras instead.

10. **Health/Mana Exploit** (`ParagonPlayer.cpp:100-104`): `RefreshParagonAura()` fully restores HP/mana outside dungeons/raids on every aura refresh (login, map change). This is exploitable for free healing.

### Code Quality

11. **Massive Code Duplication** (`ParagonPlayer.cpp:45-96`): 16 identical `RemoveAura` + `if > 0 AddAura/SetAuraStack` blocks. Should use a data-driven loop with an array of `{auraId, points}` pairs.

12. **Unused Variables**: `bool debug = true` (line 17) is never referenced. Should be removed.

13. **Unused Includes**: `ElunaIncludes.h`, `lua.h`, `lauxlib.h`, `LuaEngine.h` are included but Eluna functionality is never used.

14. **`Query()` for INSERT/UPDATE** (`ParagonPlayer.cpp:167,176,177,214,215,356,366`): Uses `CharacterDatabase.Query()` for write operations. Should use `CharacterDatabase.Execute()` since no result set is needed.

15. **XP Overflow Risk** (`ParagonPlayer.cpp:349`): `pow(1.1, paragonLevel - 1)` grows exponentially. At high levels (200+), this overflows `uint32`. The `newXP < 0` check on line 350 is also dead code since `newXP` is `uint32` (always >= 0).

16. **Duplicated Login/MapChange Logic** (`ParagonPlayer.cpp:155-202`): `OnLogin()` and `OnMapChanged()` share nearly identical DB query + aura application logic. Should extract to a shared helper.

17. **No DB Query Result Validation**: Multiple places dereference query results without null checks or column count validation.

18. **`GetRawValue()` Usage** (`ParagonPlayer.cpp:112,135`): `ObjectGuid::GetRawValue()` returns a `uint64`, but it's stored in `uint32 characterID`. This truncates the GUID on 64-bit systems. Should use `GetCounter()` for the low part or pass the GUID properly.

### Potential Enhancements

- **In-Memory Caching**: Cache paragon level/points in player data to avoid DB queries on every map change
- **Configurable System**: Actually read from `mod_paragon.conf.dist` to allow server admins to tune XP rates, points per level, enable/disable, etc.
- **Anti-Farm Measures**: Cooldown or diminishing returns on XP from repeated kills
- **Point Allocation via NPC**: Currently no gossip menu to allocate points (only reset). The README mentions a Lua/AIO client UI which is not included in this repo
- **Announce System**: Server-wide announcement on milestone Paragon levels
- **Max Level Cap**: No upper bound on Paragon level — may need a configurable cap
