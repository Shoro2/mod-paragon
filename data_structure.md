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
│   └── db-world/                                      # World schema (big-stat spells, NPC, item)
├── Paragon_System_LUA/
│   ├── Paragon_Server.lua                             # AIO server: Allocate/Deallocate/Reset, ApplyStatAuras
│   ├── Paragon_Client.lua                             # AIO client: frame, stat rows, tabs, +/- buttons
│   └── Paragon_Data.lua                               # Stat definitions, MAX_POINTS, sound IDs, DB helpers
├── src/
│   ├── Paragon_loader.cpp                             # Loader: Addmod_paragonScripts() (~550 B)
│   ├── ParagonPlayer.cpp                              # Main logic: PlayerScript+UnitScript+WorldScript (~26 KB)
│   ├── ParagonNPC.cpp                                 # CreatureScript for npc_paragon (~1.8 KB)
│   └── ParagonUtils.h                                 # Header (~200 B)
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
| `conf/mod_paragon.conf.dist` | 30+ options: aura IDs (small/big), big-aura IDs (`Paragon.IdBig*`), MaxStats[17], MaxLevel, XP rewards, PartyReduce |
| `data/sql/db-characters/base/character_paragon_create.sql` | Account level/XP table |
| `data/sql/db-characters/base/character_paragon_points_create.sql` | Per-character stat allocation (17 columns) |
| `data/sql/db-characters/updates/add_plifeleech_column.sql` | Migration for the Life Leech column |
| `data/sql/db-world/base/paragon_currency_item.sql` | Item template for Paragon points (item 920920) |
| `data/sql/db-world/base/paragon_big_stat_spells.sql` | 17 spell_dbc inserts for big-stat auras (IDs 100201-100227) |
| `Paragon_System_LUA/Paragon_Data.lua` | Data model: 17 stat definitions with `auraId`, `bigAuraId`, category, tooltip; `MAX_POINTS` table |
| `Paragon_System_LUA/Paragon_Server.lua` | AIO handlers: `RequestData`, `AllocatePoint`, `DeallocatePoint`; `ApplyStatAuras` helper |
| `Paragon_System_LUA/Paragon_Client.lua` | UI: `ParagonFrame`, category tabs, stat rows, +/- buttons (Shift = ×10), ESC menu button |
| `src/Paragon_loader.cpp` | `Addmod_paragonScripts()` calls `AddParagonPlayerScripts`, `AddMyNPCScripts`, `AddParagonConfigScripts` |
| `src/ParagonPlayer.cpp` | contains `ParagonPlayer` (PlayerScript), `ParagonLifeLeech` (UnitScript), `ParagonConfig` (WorldScript), cache map |
| `src/ParagonNPC.cpp` | CreatureScript `npc_paragon`: gossip "Info / Reset" |
| `src/ParagonUtils.h` | Forward declarations |
| `apps/ci/ci-codestyle.sh` | Codestyle CI check (4-space, LF, type position, etc.) |

## Size notes (as of 2026-05-01)

- `ParagonPlayer.cpp` ~26 KB → readable in one piece (at the limit). Use chunked reads if needed.
- All other .cpp/.h: < 2 KB
- Lua files: each < 30 KB (presumably)
- SQL files: each < 5 KB

## External dependencies

- **azerothcore-wotlk** (core): `PlayerScript`, `UnitScript`, `WorldScript`, `CreatureScript`, prepared statement API, `sConfigMgr`.
- **AIO framework**: `lua_scripts/AIO.lua` + dependencies from `share-public/AIO_Server/`.
- **Custom Spell.dbc**: 17 big-stat aura IDs (100201-100227) + 17 small-stat aura IDs (100001-100027) must exist in the server Spell.dbc.
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
| `spell_dbc` | DB override for big-stat auras (17 entries IDs 100201-100227) |
| `creature_template` | NPC `npc_paragon` (entry 900100, ScriptName `npc_paragon`) |
| `item_template` | Paragon point item (entry 920920) |
| `npc_text` | Gossip greeting (`197760`) |

## What is not where?

- **No custom DBC files in this repo** — DBC patches live in `azerothcore-wotlk/share/dbc/Spell.dbc`.
- **No build slot** — included in `modules/` via AzerothCore auto-detection.
- **No unit tests** — only CI codestyle.
