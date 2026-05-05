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
       ▼ character_paragon_points → invisible stack auras (100xxx) on player
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
| **Custom spells** | 100000 (level counter), 100001-100005 (Str/Int/Agi/Spi/Sta), 100016-100027 (all combat ratings + LifeLeech) | see [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md) |
| | 100201-100227 | "Big" counterparts for stats > 255 (stack ×100) |
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
- Level cap: `Paragon.MaxLevel` (0 = unlimited)
- Aura IDs: `Paragon.IdStr`, `Paragon.IdInt`, …, `Paragon.IdLifeLeech` (each individually overridable)
- Max points per stat: `Paragon.MaxStr`, `Paragon.MaxInt`, … (default 255 each, 0 = unlimited)
- XP rewards: `Paragon.XpEliteDungeon`, `Paragon.XpRaidBoss`, …
- Party XP reduce: `Paragon.PartyReducePct`
- LifeLeech %: `Paragon.LifeLeechPct = 0.5` (default)

Full list with defaults: [`functions.md`](./functions.md#configuration).

## What this module does **not** do

- **no** item enchanting → that's the standalone `mod-paragon-itemgen`
- **no** talents / specs → Paragon stats are pure numeric bonuses
- **no** PvP toggle (stats apply in PvP just like in PvE)
- **no** anti-farm protection (see [`todo.md`](./todo.md))

## Architecture notes

- **Hybrid C++/Lua**: both layers write to `character_paragon_points`. C++ is the single source of truth for aura application; Lua/AIO is the UI for allocation. Race conditions are theoretically possible but rare in practice due to UI latency — see [`todo.md`](./todo.md).
- **Stack limit workaround**: WoW auras stack up to 255. For stats > 255 there are paired "big" auras (stack × 100) and "small" auras (stack × 1). Allocation `N`: `big = N/100`, `small = N%100`.
- **LifeLeech (100027)**: heals a configurable percentage of damage dealt. Also works through pets/totems via `Unit::GetCharmerOrOwnerPlayerOrPlayerItself()`.

## License

GPL v2.
