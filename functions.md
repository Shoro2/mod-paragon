# Functions & mechanics — mod-paragon

> Detailed function and mechanics reference. For content/purpose docs see `CLAUDE.md`.

## Module loader

### `Addmod_paragonScripts()` (`src/Paragon_loader.cpp`)
Calls three sub-loaders:
- `AddParagonPlayerScripts()` — `ParagonPlayer` (PlayerScript) + `ParagonLifeLeech` (UnitScript) + `ParagonConfig` (WorldScript)
- `AddMyNPCScripts()` — `npc_paragon` CreatureScript (gossip)
- `AddParagonReapplyScripts()` — `spell_paragon_reapply` (SpellScript, the Lua→C++ reapply bridge)

## Class overview

| Class | Type | Purpose |
|--------|-----|-------|
| `ParagonPlayer` | `PlayerScript` | XP grant, level-up, stat apply on login + reapply hooks |
| `ParagonLifeLeech` | `UnitScript` | Implements stat #17 (Life Leech) via `OnDamage` |
| `ParagonConfig` | `WorldScript` | `OnAfterConfigLoad` → `sConfigMgr->GetOption<>()` calls |
| `spell_paragon_reapply` | `SpellScript` | Spell 100028: re-derives + applies stats after a Lua DB write |
| `npc_paragon` | `CreatureScript` | Gossip menu for NPC 900100 |

## XP system

### XP sources (each per player to all map group members)

| Encounter type | XP |
|---------------|----|
| Regular elite | 1 |
| Dungeon elite | 1 |
| Heroic dungeon elite | 2 |
| Dungeon boss | 3 |
| Heroic dungeon boss | 5 |
| Raid boss | 10 |
| World boss | 20 |
| Daily/weekly quest | 3 |

### Level formula
`xpForLevel = 100 * pow(1.1, level-1)`. The value is stored in `character_paragon.xp` and **counts down** to 0. At 0 → level-up, new XP calculated, `unspent_points += 5`.

Overflow protection: `pow()` with `int64` accumulation, `std::min()` cap at `INT32_MAX`. With `Paragon.MaxLevel > 0` and the cap reached, no further XP gain is accepted.

### Group XP
`OnCreatureKill` iterates group members. Only members on the same map count. The PartyReduce factor (`Paragon.PartyReduce`, default 1.0) scales XP per member.

## In-memory cache

```cpp
// Account-wide level/XP
std::unordered_map<uint32 /*accountID*/, ParagonCache> sParagonAcct;
struct ParagonCache { uint32 level; uint32 xp; };

// Per-character exact applied stat points (diff-based reapply + the Life Leech
// value read in OnDamage). Index matches the 17 stats; index 16 = Life Leech.
std::unordered_map<ObjectGuid, std::array<uint32, 17>> sParagonApplied;

std::mutex sParagonMutex;  // guards both maps
```

- **Login** → SELECT level/XP into `sParagonAcct`; `ApplyParagonStatEffects` (purges legacy auras, full apply, snapshot starts empty). A fresh/missing account row also applies stats (covers a points row surviving an account-row loss) and caches `level=1, xp=100` to mirror `CHAR_INS_PARAGON`.
- **MapChange / Resurrect** → `ApplyParagonStatEffects` (cheap PK reconcile against the DB; diff-based → no-op when nothing drifted; self-heals snapshot-vs-DB divergence) + `EnsureParagonAuras` (re-assert the Mount Speed aura when points did not change).
- **XP gain / level-up** → update `sParagonAcct`, async DB UPDATE.
- **Logout** → erase both cache entries (nothing is persisted aura-side).

`GetParagonLevel(Player*)` returns the true level (cache→DB) for cross-module reads above 255.

## Stat application system

Each stat is applied **once with its full value** via the cleanest core API — no
stacking auras, so the `uint8` 255 stack ceiling never applies (effect amounts
are `int32`). Per-point values (unchanged): Str/Int/Agi/Spi/Sta/Haste/ArmorPen/
ManaRegen = 5, SpellPower/Crit/Hit/Parry/Dodge = 10, Block = 4, Expertise = 3,
MountSpeed = 1, LifeLeech = 0.1%/pt.

| # (idx) | Stat | Mechanism |
|----|------|-----------|
| 0-4 | Str/Int/Agi/Spi/Sta | `HandleStatFlatModifier(UNIT_MOD_STAT_x, BASE_VALUE, n*5)` + `UpdateStatBuffMod` |
| 5 | Haste | `ApplyRatingMod(CR_HASTE_MELEE/RANGED/SPELL, n*5)` |
| 6 | ArmorPen | `ApplyRatingMod(CR_ARMOR_PENETRATION, n*5)` |
| 7 | SpellPower | `ApplySpellPowerBonus(n*10)` |
| 8 | Crit | `ApplyRatingMod(CR_CRIT_MELEE/RANGED/SPELL, n*10)` |
| 9 | MountSpeed | single aura 100029 (run+swim), `CastCustomSpell` + `SPELLVALUE_BASE_POINT0/1` |
| 10 | ManaRegen | `ApplyManaRegenBonus(n*5)` |
| 11 | Hit | `ApplyRatingMod(CR_HIT_MELEE/RANGED/SPELL, n*10)` |
| 12-15 | Block/Expertise/Parry/Dodge | `ApplyRatingMod(CR_BLOCK/EXPERTISE/PARRY/DODGE, n*{4,3,10,10})` |
| 16 | Life Leech | no stat applied; value read from `sParagonApplied` in `OnDamage` |

Note: the module's primary-stat index order (Str, **Int, Agi, Spi, Sta**) differs
from the core `Stats` enum, so `ApplyStat` maps via `kPrimaryStat[]`.

### `ReapplyParagonStats(Player*, uint32 const desired[17])`

Diff-based and idempotent. For each stat: clamp to `conf_MaxStats[i]`, and if the
desired value differs from the per-player snapshot, remove the old amount
(`ApplyStat(..., apply=false)`) then add the new (`apply=true`); finally store the
snapshot. `ApplyParagonStatEffects(Player*)` reads `character_paragon_points` and
calls this; `ClearParagonStats(Player*)` calls it with all-zeros (NPC reset).

Direct modifiers survive map change, death, item equip and `.reset stats` (the
core re-applies item/aura mods symmetrically and never zeroes our additions), so
no decay. Only the Mount Speed aura may be stripped by a game event; `EnsureParagonAuras`
re-asserts it from the snapshot on map change / resurrect.

`ApplyParagonStatEffects` additionally begins with `RemoveLegacyParagonAuras`
(100001-100005, 100016-100027, 100201-100227 — the 100006-100015 gap holds
unrelated FL spells and must survive), so a stale pre-redesign Lua deployment
or an old `character_aura` row can never double-count a stat mid-session.
**Deploy contract:** `lua_scripts/Paragon_System/` on the server MUST match
`Paragon_System_LUA/` in this repo — the pre-redesign Lua stacks visible
legacy auras and never casts trigger 100028, silently desyncing the snapshot
(that drift caused the 2026-07 "stats vanish after wipes/teleports" report).

## NPC `npc_paragon` (CreatureScript, entry 900100)

Gossip options:
1. **"Show Info"** — lists current allocations.
2. **"Reset Points"** — async `CHAR_UPD_PARAGON_POINTS_RESET` (zeroes all 17 columns, refunds into `unspent_points`), then `ClearParagonStats(player)` applies zero directly (race-free — does not re-read the not-yet-committed row).

Greeting text ID: `197760` (`npc_text` table).

## Life Leech (`ParagonLifeLeech::OnDamage`)

```cpp
void OnDamage(Unit* attacker, Unit* victim, uint32& damage)
{
    Player* player = attacker->GetCharmerOrOwnerPlayerOrPlayerItself();
    if (!player) return;

    // Self/friendly damage check — no self-heal
    if (victim == player ||
        victim->GetCharmerOrOwnerPlayerOrPlayerItself() == player) return;

    // Life Leech points come from the in-memory snapshot (index 16), not an
    // aura — so they cannot be lost on relog / dispel.
    uint32 leechPoints = sParagonApplied[player->GetGUID()][16]; // under mutex
    if (!leechPoints) return;

    float healPct = leechPoints * conf_LifeLeechPct;            // % of damage
    uint32 heal = uint32(damage * healPct / 100.0f);
    if (heal) Unit::DealHeal(player, player, heal);
}
```

Works for:
- Player direct (Mage Fireball, Priest Smite, Warlock Shadow Bolt)
- Player Pet (Demonology Felguard, Frost Mage Water Elemental, BM Hunter Pets)
- Player Totem (all Shaman specs)
- Charmed Unit (Mind Control, Frost DK Dancing Rune Weapon)

Excludes:
- Self damage (fall damage, environmental, own AoE splashes onto self)
- Friendly fire on own pets/totems

## AIO layer (Lua)

### Server handlers (`Paragon_Server.lua`)

| Handler | Args | Effect |
|---------|------|---------|
| `RequestData` | — | sends `categories`, `stats`, `allocations`, `unspent_points` to client |
| `AllocatePoint` | `statId, amount` | clamped to available points + MaxStat; atomic `UPDATE character_paragon_points`, then `player:CastSpell(player, 100028, true)` → C++ reapply |
| `DeallocatePoint` | `statId, amount` | clamped to current allocation; refunds onto `unspent_points`; same reapply trigger |

Stat application is C++-only; the Lua side never touches auras directly.

### Client UI (`Paragon_Client.lua`)

| Frame/element | Purpose |
|---------------|-------|
| `ParagonFrame` | Main window (620×440, draggable, ESC-close) |
| Category tabs (left) | Primary / Offensive / Defensive / Utility |
| `statRows[1..8]` | Icon, name, tooltip, "X/MAX" display, +/- |
| +/- buttons | Shift+click = `amount=10`, otherwise 1 |
| ESC menu button | Game menu entry "Paragon" |

### `Paragon_Data.lua`

- `Paragon.STATS[]` — 17 entries with `id, name, tooltip, icon, dbColumn, maxPoints, categoryId` (no aura IDs — stats are applied in C++)
- `Paragon.REAPPLY_SPELL = 100028` — trigger spell cast after a DB write
- `Paragon.MAX_POINTS[]` — per stat, must be in sync with `mod_paragon.conf`
- `Paragon.GetAllocations(characterID)` / `UpdateAllocationAndUnspent(...)` — DB access (all numerics `tonumber`-coerced; `dbColumn` whitelisted)
- Race/gender-specific sound IDs for the "Not enough money" voice

## Configuration options (excerpt)

| Key | Default | Effect |
|-----------|---------|---------|
| `Paragon.Enable` | true | master toggle |
| `Paragon.MaxLevel` | 666 | 0 = unlimited |
| `Paragon.MaxStr`-`Paragon.MaxLifeLeech` | 666 | per-stat cap (0 = unlimited) |
| `Paragon.IdLevel` | 100000 | level marker / "has paragon" aura |
| `Paragon.MountSpeedSpellId` | 100029 | Mount Speed aura (run + swim) |
| `Paragon.LifeLeechPct` | 0.1 | % heal per point |
| `Paragon.XPElite`-`Paragon.XPWorldBoss` | see table | XP rewards |

## Known limitations

- **SQL injection in Lua**: mitigated — `AllocatePoint`/`DeallocatePoint` validate `statId`/`amount` via the shared `Dep_Validation` lib (permissive shim fallback if not deployed), numerics are `tonumber`-coerced, and `dbColumn` is whitelisted from `Paragon.STATS`.
- **Level marker caps at 255**: spell 100000's stack is `uint8`; use `GetParagonLevel(Player*)` for the true level. Cross-module readers must not use `GetAuraCount(100000)`.
- **No anti-farm measures** — no cooldowns on XP sources, no diminishing returns on repeated kills of the same mob entry.

## Test commands (for GMs)

```
.modify <stat>          # verify primary-stat totals on the character sheet
.npc add 900100         # spawn Paragon NPC
# Set points directly for testing, then relog:
#   UPDATE character_paragon_points SET pstrength = 666 WHERE characterID = ?;
#   UPDATE character_paragon SET level = 666 WHERE accountID = ?;
```
