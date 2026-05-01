# Datei- und Verzeichnisstruktur — mod-paragon

> Statisches Inventar. Bei Hinzufügen/Löschen von Files hier mitpflegen.

## Tree

```
mod-paragon/
├── conf/
│   └── mod_paragon.conf.dist                          # Konfig-Template (~30 Optionen)
├── data/sql/
│   ├── db-auth/                                       # (ggf. leer / reserviert)
│   ├── db-characters/                                 # Character-Schema (paragon Tabellen)
│   └── db-world/                                      # World-Schema (Big-Stat-Spells, NPC, Item)
├── Paragon_System_LUA/
│   ├── Paragon_Server.lua                             # AIO-Server: Allocate/Deallocate/Reset, ApplyStatAuras
│   ├── Paragon_Client.lua                             # AIO-Client: Frame, Stat-Rows, Tabs, +/- Buttons
│   └── Paragon_Data.lua                               # Stat-Definitionen, MAX_POINTS, Sound-IDs, DB-Helper
├── src/
│   ├── Paragon_loader.cpp                             # Loader: Addmod_paragonScripts() (~550 B)
│   ├── ParagonPlayer.cpp                              # Hauptlogik: PlayerScript+UnitScript+WorldScript (~26 KB)
│   ├── ParagonNPC.cpp                                 # CreatureScript für npc_paragon (~1.8 KB)
│   └── ParagonUtils.h                                 # Header (~200 B)
├── apps/ci/ci-codestyle.sh                            # CI-Codestyle-Validation
├── include.sh                                          # Build-Integration
├── pull_request_template.md                            # GitHub PR-Template
├── CLAUDE.md                                           # Detaillierte Inhalts-Doku
├── log.md                                              # Commit-Log (modular)
├── data_structure.md                                   # Diese Datei
└── functions.md                                        # Mechanik- und Funktions-Referenz
```

## Datei-Zwecke

| Datei | Zweck |
|-------|-------|
| `conf/mod_paragon.conf.dist` | 30+ Optionen: Aura-IDs (klein/groß), Big-Aura-IDs (`Paragon.IdBig*`), MaxStats[17], MaxLevel, XP-Belohnungen, PartyReduce |
| `data/sql/db-characters/base/character_paragon_create.sql` | Account-Level/XP-Tabelle |
| `data/sql/db-characters/base/character_paragon_points_create.sql` | Per-Char Stat-Allokation (17 Spalten) |
| `data/sql/db-characters/updates/add_plifeleech_column.sql` | Migration für Life-Leech-Spalte |
| `data/sql/db-world/base/paragon_currency_item.sql` | Item-Template für Paragon-Punkte (Item 920920) |
| `data/sql/db-world/base/paragon_big_stat_spells.sql` | 17 spell_dbc-Inserts für Big-Stat-Auras (IDs 100201-100227) |
| `Paragon_System_LUA/Paragon_Data.lua` | Datenmodell: 17 Stat-Definitionen mit `auraId`, `bigAuraId`, Kategorie, Tooltip; `MAX_POINTS`-Tabelle |
| `Paragon_System_LUA/Paragon_Server.lua` | AIO-Handler: `RequestData`, `AllocatePoint`, `DeallocatePoint`; `ApplyStatAuras`-Helper |
| `Paragon_System_LUA/Paragon_Client.lua` | UI: `ParagonFrame`, Kategorie-Tabs, Stat-Rows, +/- Buttons (Shift = ×10), ESC-Menu-Button |
| `src/Paragon_loader.cpp` | `Addmod_paragonScripts()` ruft `AddParagonPlayerScripts`, `AddMyNPCScripts`, `AddParagonConfigScripts` |
| `src/ParagonPlayer.cpp` | enthält `ParagonPlayer` (PlayerScript), `ParagonLifeLeech` (UnitScript), `ParagonConfig` (WorldScript), Cache-Map |
| `src/ParagonNPC.cpp` | CreatureScript `npc_paragon`: Gossip "Info / Reset" |
| `src/ParagonUtils.h` | Forward-Declarations |
| `apps/ci/ci-codestyle.sh` | Codestyle-CI-Check (4-Space, LF, Type-Pos, etc.) |

## Größenhinweise (Stand: 2026-05-01)

- `ParagonPlayer.cpp` ~26 KB → einzeln lesbar (am Limit). Bei Bedarf chunked Read.
- alle anderen .cpp/.h: < 2 KB
- Lua-Files: jeweils < 30 KB (vermutlich)
- SQL-Files: jeweils < 5 KB

## Externe Abhängigkeiten

- **azerothcore-wotlk** (Core): `PlayerScript`, `UnitScript`, `WorldScript`, `CreatureScript`, Prepared-Statement-API, `sConfigMgr`.
- **AIO Framework**: `lua_scripts/AIO.lua` + Dependencies aus `share-public/AIO_Server/`.
- **Custom Spell.dbc**: 17 Big-Stat-Aura-IDs (100201-100227) + 17 Small-Stat-Aura-IDs (100001-100027) müssen in der Server-Spell.dbc existieren.
- **mod-paragon-itemgen**: liest `character_paragon.level` zur Item-Skalierung.

## DB-Tabellen

### `acore_characters`
| Tabelle | PK | Inhalt |
|---------|----|--------|
| `character_paragon` | `accountID` | Account-Level + XP (zählt herunter) |
| `character_paragon_points` | `characterID` | `unspent_points` + 17 Stat-Spalten |

### `acore_world`
| Tabelle | Inhalt |
|---------|--------|
| `spell_dbc` | DB-Override für Big-Stat-Auras (17 Einträge IDs 100201-100227) |
| `creature_template` | NPC `npc_paragon` (Entry 900100, ScriptName `npc_paragon`) |
| `item_template` | Paragon-Punkt-Item (Entry 920920) |
| `npc_text` | Gossip-Greeting (`197760`) |

## Wo ist was nicht?

- **Keine Custom-DBC-Files in diesem Repo** — DBC-Patches liegen in `azerothcore-wotlk/share/dbc/Spell.dbc`.
- **Kein Build-Slot** — wird via AzerothCore Auto-Detection in `modules/` eingebunden.
- **Keine Unit-Tests** — nur CI-Codestyle.
