# File and directory structure — mod-paragon

> Static inventory. Maintain this when adding/removing files.

## Tree

```
mod-paragon/
├── conf/
│   └── mod_paragon.conf.dist                          # Config template (~30 options)
├── data/sql/
│   ├── db-auth/                                       # (possibly empty / reserved)
│   ├── db-characters/                                 # Character schema (paragon tables)
│   └── db-world/                                      # World schema (spells, NPC, item)
├── Paragon_System_LUA/
│   ├── Paragon_Server.lua                             # AIO server: Allocate/Deallocate; casts reapply trigger
│   ├── Paragon_Client.lua                             # AIO client: frame, stat rows, tabs, +/- buttons
│   └── Paragon_Data.lua                               # Stat definitions, MAX_POINTS, sound IDs, DB helpers
├── src/
│   ├── Paragon_loader.cpp                             # Loader: Addmod_paragonScripts()
│   ├── ParagonPlayer.cpp                              # Main logic: PlayerScript+UnitScript+WorldScript
│   ├── ParagonReapply.cpp                             # SpellScript 100028 (Lua→C++ reapply bridge)
│   ├── ParagonNPC.cpp                                 # CreatureScript for npc_paragon
│   └── ParagonUtils.h                                 # Header (function declarations)
├── apps/ci/ci-codestyle.sh                            # CI codestyle validation
├── include.sh                                          # Build integration
├── pull_request_template.md                            # GitHub PR template
├── CLAUDE.md                                           # Detailed content doc
├── log.md                                              # Commit log (modular)
├── data_structure.md                                   # This file
└── functions.md                                        # Mechanics and function reference
```

## File purposes

| File | Purpose |
|-------|-------|
| `conf/mod_paragon.conf.dist` | options: `IdLevel`, `MountSpeedSpellId`, MaxStats[17], MaxLevel (666), XP rewards, LifeLeechPct |
| `data/sql/db-characters/base/character_paragon_create.sql` | Account level/XP table |
| `data/sql/db-characters/base/character_paragon_points_create.sql` | Per-character stat allocation (17 columns) |
| `data/sql/db-characters/updates/add_plifeleech_column.sql` | Migration for the Life Leech column |
| `data/sql/db-characters/updates/remove_legacy_stat_auras.sql` | Purge saved legacy stat auras from `character_aura` |
| `data/sql/db-world/base/paragon_currency_item.sql` | Item template for Paragon points (item 920920) |
| `data/sql/db-world/base/paragon_fix_strength_spell.sql` | Removes a bad `spell_dbc` override of 100001 |
| `data/sql/db-world/base/paragon_mountspeed_spell.sql` | spell_dbc 100029 (Mount Speed aura: run + swim) |
| `data/sql/db-world/base/paragon_reapply_spell.sql` | spell_dbc 100028 + `spell_script_names` (reapply trigger) |
| `data/sql/db-world/updates/remove_legacy_stat_spells.sql` | Drops obsolete `spell_dbc` rows (100201-100227, 100027) |
| `data/sql/db-world/updates/fix_paragon_spell_attributes.sql` | Bitwise-fixes 100028/100029 attributes (DO_NOT_DISPLAY 0x80, death-persist Ex3 0x130000, Ex5 0x60000) |
| `Paragon_System_LUA/Paragon_Data.lua` | Data model: 17 stat definitions (`dbColumn`, `maxPoints`, …), `REAPPLY_SPELL`, `MAX_POINTS`, DB helpers |
| `Paragon_System_LUA/Paragon_Server.lua` | AIO handlers: `RequestData`, `AllocatePoint`, `DeallocatePoint` (cast reapply trigger after DB write) |
| `Paragon_System_LUA/Paragon_Client.lua` | UI: `ParagonFrame`, category tabs, stat rows, +/- buttons (Shift = ×10), ESC menu button |
| `src/Paragon_loader.cpp` | `Addmod_paragonScripts()` calls `AddParagonPlayerScripts`, `AddMyNPCScripts`, `AddParagonReapplyScripts` |
| `src/ParagonPlayer.cpp` | `ParagonPlayer` (PlayerScript), `ParagonLifeLeech` (UnitScript), `ParagonConfig` (WorldScript); direct stat APIs + caches |
| `src/ParagonReapply.cpp` | `spell_paragon_reapply` SpellScript: re-applies stats on cast of 100028 |
| `src/ParagonNPC.cpp` | CreatureScript `npc_paragon`: gossip "Info / Reset" |
| `src/ParagonUtils.h` | Forward declarations (`ApplyParagonStatEffects`, `ReapplyParagonStats`, `ClearParagonStats`, `GetParagonLevel`, `IncreaseParagonXP`) |
| `apps/ci/ci-codestyle.sh` | Codestyle CI check (4-space, LF, type position, etc.) |

## Size notes (as of 2026-05-01)

- `ParagonPlayer.cpp` ~26 KB → readable in one piece (at the limit). Use chunked reads if needed.
- All other .cpp/.h: < 2 KB
- Lua files: each < 30 KB (presumably)
- SQL files: each < 5 KB

## External dependencies

- **azerothcore-wotlk** (core): `PlayerScript`, `UnitScript`, `WorldScript`, `CreatureScript`, prepared statement API, `sConfigMgr`.
- **AIO framework**: `lua_scripts/AIO.lua` + dependencies from `share-public/AIO_Server/`.
- **Custom Spell.dbc**: only the level marker 100000 is still used from the binary Spell.dbc. Stats are applied via direct core APIs; Mount Speed (100029) and the reapply trigger (100028) are server-side `spell_dbc` rows (no client DBC entry needed).
- **mod-paragon-itemgen**: reads `character_paragon.level` for item scaling.

## DB tables

### `acore_characters`
| Table | PK | Contents |
|---------|----|--------|
| `character_paragon` | `accountID` | Account level + XP (counts down) |
| `character_paragon_points` | `characterID` | `unspent_points` + 17 stat columns |

### `acore_world`
| Table | Contents |
|---------|--------|
| `spell_dbc` | Server-side spells 100028 (reapply trigger) + 100029 (Mount Speed) |
| `spell_script_names` | Binds 100028 → `spell_paragon_reapply` |
| `creature_template` | NPC `npc_paragon` (entry 900100, ScriptName `npc_paragon`) |
| `item_template` | Paragon point item (entry 920920) |
| `npc_text` | Gossip greeting (`197760`) |

## What is not where?

- **No custom DBC files in this repo** — DBC patches live in `azerothcore-wotlk/share/dbc/Spell.dbc`.
- **No build slot** — included in `modules/` via AzerothCore auto-detection.
- **No unit tests** — only CI codestyle.
