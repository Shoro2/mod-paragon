# Functions & mechanics — mod-paragon

> Detailed function and mechanics reference. For content/purpose docs see `CLAUDE.md`.

## Module loader

### `Addmod_paragonScripts()` (`src/Paragon_loader.cpp`)
Calls three sub-loaders:
- `AddParagonPlayerScripts()` — `ParagonPlayer` (PlayerScript) + `ParagonLifeLeech` (UnitScript) + `ParagonConfig` (WorldScript)
- `AddMyNPCScripts()` — `npc_paragon` CreatureScript (gossip)
- (additionally cache init in WorldScript)

## Class overview

| Class | Type | Purpose |
|--------|-----|-------|
| `ParagonPlayer` | `PlayerScript` | XP grant, level-up, aura apply on login/map change |
| `ParagonLifeLeech` | `UnitScript` | Implements stat #17 (Life Leech) via `OnDamage` |
| `ParagonConfig` | `WorldScript` | `OnAfterConfigLoad` → 30+ `sConfigMgr->GetOption<>()` calls |
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
std::unordered_map<uint32 /*accountID*/, ParagonCache> _cache;
std::mutex _cacheMutex;

struct ParagonCache {
    uint32 level;
    uint32 xp;
    bool dirty;
};
```

- **Login** → SELECT, populate cache.
- **MapChange** → reads from cache, no DB call.
- **XP gain / level-up** → update cache, async DB UPDATE.
- **Logout** → invalidate cache.

Mutex protection on every access. With multiple logins of the same account (multi-box), the cache is **not** duplicated — all sessions share the same entry.

## Stat aura system

### 17 stats

| ID | Name | Aura small | Aura big | Scaling |
|----|------|-----------|----------|-----------|
| 1 | Strength | 100001 | 100201 | big = small × 100 |
| 2 | Intellect | 100002 | 100202 | ditto |
| 3 | Agility | 100003 | 100203 | ditto |
| 4 | Spirit | 100004 | 100204 | ditto |
| 5 | Stamina | 100005 | 100205 | ditto |
| 6-16 | Haste, ArmorPen, SpellPower, Crit, MountSpeed, ManaRegen, Hit, Block, Expertise, Parry, Dodge | 100016-100026 | 100216-100226 | ditto |
| 17 | Life Leech | 100027 | 100227 | ditto |

All IDs **configurable** via `Paragon.Id<Stat>` and `Paragon.IdBig<Stat>`.

### Big+small allocation

The aura stack limit is `uint8` = 255. Workaround = aura pair:

```
N = unspent points to allocate
big_stacks   = N / 100
small_stacks = N % 100
```

Example: 666 Strength = 6×big stack (à 500 stat value) + 66×small stack (à 5) = 3330 effective value. Big auras have a 100× larger `BasePoints` value in `spell_dbc`.

### `RefreshParagonAura(Player*, uint32 const points[17])`

Data-driven loop:
```cpp
for (uint8 i = 0; i < 17; ++i) {
    uint32 pts = points[i];
    uint32 big = pts / 100;
    uint32 small = pts % 100;
    ApplyAuraStack(player, conf_AuraIds[i], small);
    ApplyAuraStack(player, conf_BigAuraIds[i], big);
}
```

Where `ApplyAuraStack(player, auraId, n)`:
- `n == 0` → `player->RemoveAura(auraId);`
- `n > 0` → `player->AddAura(auraId, player); player->GetAura(auraId)->SetStackAmount(n);`

**Important**: no more `RestoreHealth()` or `RestoreMana()` — the previous health/mana exploit on aura refresh has been fixed.

## NPC `npc_paragon` (CreatureScript, entry 900100)

Gossip options:
1. **"Show Info"** — lists current allocations.
2. **"Reset Points"** — sets all 17 columns to 0, refunds points into the `unspent_points` field, calls `RefreshParagonAura` again.

Greeting text ID: `197760` (`npc_text` table).

## Life Leech (`ParagonLifeLeech::OnDamage`)

```cpp
void OnDamage(Unit* attacker, Unit* victim, uint32& damage, SpellInfo const* spellInfo)
{
    Player* owner = attacker->GetCharmerOrOwnerPlayerOrPlayerItself();
    if (!owner) return;

    // Self/friendly damage check
    Player* victimOwner = victim->GetCharmerOrOwnerPlayerOrPlayerItself();
    if (victimOwner == owner) return;  // no self-heal

    uint32 leechStacks = owner->GetAuraCount(conf_AuraIds[16])      // small
                       + owner->GetAuraCount(conf_BigAuraIds[16]) * 100; // big
    if (!leechStacks) return;

    float pct = leechStacks * conf_LifeLeechPct / 100.0f;
    int32 heal = static_cast<int32>(damage * pct);
    if (heal > 0)
        owner->HealBySpell(SpellHealInfo{owner, owner, /*spellId*/ 100027, uint32(heal)});
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
| `AllocatePoint` | `statId, amount` | clamped to available points + MaxStat; `UPDATE character_paragon_points`, re-applies `ApplyStatAuras` |
| `DeallocatePoint` | `statId, amount` | clamped to current allocation; refunds onto `unspent_points` |

### Client UI (`Paragon_Client.lua`)

| Frame/element | Purpose |
|---------------|-------|
| `ParagonFrame` | Main window (620×440, draggable, ESC-close) |
| Category tabs (left) | Primary / Offensive / Defensive / Utility |
| `statRows[1..8]` | Icon, name, tooltip, "X/MAX" display, +/- |
| +/- buttons | Shift+click = `amount=10`, otherwise 1 |
| ESC menu button | Game menu entry "Paragon" |

### `Paragon_Data.lua`

- `Paragon.STATS[]` — 17 entries with `id, name, category, icon, tooltip, auraId, bigAuraId, dbColumn`
- `Paragon.MAX_POINTS[]` — per stat, must be in sync with `mod_paragon.conf`
- `Paragon.GetAllocations(characterID)` — DB query against `character_paragon_points`
- Race/gender-specific sound IDs for the "Not enough money" voice

## Configuration options (excerpt)

| Key | Default | Effect |
|-----------|---------|---------|
| `Paragon.Enable` | true | master toggle |
| `Paragon.MaxLevel` | 666 | 0 = unlimited |
| `Paragon.MaxStr`-`Paragon.MaxLifeLeech` | 666 | per-stat cap (0 = unlimited) |
| `Paragon.IdStr` | 100001 | small-aura IDs |
| `Paragon.IdBigStr` | 100201 | big-aura IDs (default = small + 200) |
| `Paragon.LifeLeechPct` | 0.5 | % heal per stack |
| `Paragon.XpPerEliteRegular`-`Paragon.XpPerWorldBoss` | see table | XP rewards |
| `Paragon.PartyReduce` | 1.0 | multiplier for group XP |

## Known limitations

- **SQL injection risk in Lua**: `CharDBExecute` with string concatenation (Eluna without prepared statements). Validation in the server handler is necessary.
- **C++ and Lua can collide** — both write the same DB table. Today the logic converges, but race conditions during very fast allocation are theoretically possible.
- **No anti-farm measures** — no cooldowns on XP sources, no diminishing returns on repeated kills of the same mob entry.

## Test commands (for GMs)

```
.aura 100001    # apply Strength small (for verification)
.aura 100201    # Strength big
.aura 100000    # level counter
.npc add 900100 # spawn Paragon NPC
```
