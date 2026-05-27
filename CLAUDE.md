# mod-paragon

> Read [`INDEX.md`](./INDEX.md) first. Mechanics & hooks: [`functions.md`](./functions.md). Folder layout: [`data_structure.md`](./data_structure.md). Open items: [`todo.md`](./todo.md). Commit trail: [`log.md`](./log.md).

## What is the module?

AzerothCore module for **WoW 3.3.5a (WotLK)**. Implements a **post-level-80 progression system** ("Paragon"): characters that reached the regular WotLK level cap collect additional experience points from creature kills, quests, and bosses, and receive 5 points per Paragon level to distribute across 17 stats (Strength, Intellect, Agility, Spirit, Stamina, Haste, ArmorPen, SpellPower, Crit, MountSpeed, ManaRegen, Hit, Block, Expertise, Parry, Dodge, **LifeLeech**).

**Account-wide**: level + XP shared across all characters of the account.
**Per character**: the stat distribution — every character picks its own focus.

## Role in the overall project

```
Player Kill / Quest Complete
       │
       ▼ XP gain (mod-paragon)
       │
       ▼ Level-up → 5 unspent_points → Player allocates via UI
       │
       ▼ character_paragon_points → direct core stat modifiers (C++) on player
       │
       ▼ value is read by mod-paragon-itemgen
                 (scales item bonus stats: amount = ceil(level × scaling × quality))
```

mod-paragon is the **foundation** for mod-paragon-itemgen. Without mod-paragon a character has no Paragon level → mod-paragon-itemgen would not apply bonus stats (`MinParagonLevel` check).

## Custom data

| Type | Entry | Note |
|-----|--------|-----------|
| **DB table (acore_characters)** | `character_paragon` | Account level/XP (PK `accountID`, `level`, `xp` counts **down** to 0) |
| | `character_paragon_points` | Per-character stat allocation (`unspent_points` + 17 stat columns) |
| **Custom spells** | 100000 (level marker / "has paragon" flag) | see [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md) |
| | 100028 (reapply trigger), 100029 (mount-speed aura) | server-side; stats are applied via direct core APIs, not auras |
| | 100001-100027 (legacy) | no longer applied; small spells live in binary `Spell.dbc`, kept reserved |
| **Custom NPC** | `npc_paragon` (entry **900100**) | Gossip menu for info / reset |
| **AIO handler names** | `Paragon` (server) / `Paragon_Client` (client) | Details: [`functions.md`](./functions.md#aio-handler) |
| **Slash commands** | (none) | UI opens via NPC or ESC menu button |
| **Custom items** | none — Paragon points are a **DB value** (`unspent_points`), not an item |

## XP sources (top level)

| Encounter type | XP |
|---------------|----|
| Regular/dungeon elite | 1 |
| Heroic dungeon elite | 2 |
| Dungeon boss | 3 |
| Heroic dungeon boss | 5 |
| Raid boss | 10 |
| World boss | 20 |
| Daily/weekly quest | 3 |

Group kills give XP to all group members on the same map. Level formula: `100 × 1.1^(level-1)` XP, counts **down** to 0.

## Configuration (top level)

`conf/mod_paragon.conf.dist` — ~30 options:

- Master toggle: `Paragon.Enable`
- Level cap: `Paragon.MaxLevel` (default **666**, 0 = unlimited)
- Spell IDs: `Paragon.IdLevel` (level marker), `Paragon.MountSpeedSpellId`
- Max points per stat: `Paragon.MaxStr`, `Paragon.MaxInt`, … (default **666** each, 0 = unlimited)
- XP rewards: `Paragon.XPElite`, `Paragon.XPRaidBoss`, …
- LifeLeech %: `Paragon.LifeLeechPct = 0.1` (% healed per point)

Full list with defaults: [`functions.md`](./functions.md#configuration).

## What this module does **not** do

- **no** item enchanting → that's the standalone `mod-paragon-itemgen`
- **no** talents / specs → Paragon stats are pure numeric bonuses
- **no** PvP toggle (stats apply in PvP just like in PvE)
- **no** anti-farm protection (see [`todo.md`](./todo.md))

## Architecture notes

- **C++ is the single source of truth for stat application.** Each stat is applied **once with its full value** via the core stat APIs — `HandleStatFlatModifier` (primary stats), `ApplyRatingMod` (combat ratings), `ApplySpellPowerBonus`, `ApplyManaRegenBonus`, and a single non-stacking aura for Mount Speed (spell 100029). No stacking auras → the uint8 255 stack ceiling never applies. Effect amounts are `int32`, so 666 × per-point fits trivially.
- **Deterministic reapply.** On login, stats are re-derived from `character_paragon_points` and diffed against a per-player applied snapshot (idempotent). Direct modifiers persist for the whole session (they survive map change, death, item equip, and `.reset stats`), so nothing decays. Lua/AIO only validates input + writes the DB, then casts the hidden reapply-trigger spell (100028) whose C++ SpellScript re-applies the stats.
- **Relog fix**: the old design used non-passive auras, which the core saved to `character_aura` and reloaded with stale/255-capped stacks — that was the root of the relog/decay bug. The new design stores nothing aura-side for stats, so there is nothing to lose.
- **LifeLeech**: heals `Paragon.LifeLeechPct`% of damage dealt per point. The value is read from the in-memory snapshot in `ParagonLifeLeech::OnDamage` (no aura). Works through pets/totems via `Unit::GetCharmerOrOwnerPlayerOrPlayerItself()`.
- **Level > 255**: the marker aura 100000 caps at 255 (uint8). Use `GetParagonLevel(Player*)` for the true level (up to `MaxLevel`); other modules must not read the level via `GetAuraCount(100000)`.

## License

GPL v2.
