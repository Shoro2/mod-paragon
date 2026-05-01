# Funktionen & Mechaniken — mod-paragon

> Detaillierte Funktions- und Mechanik-Referenz. Inhalts-/Zweck-Doku siehe `CLAUDE.md`.

## Modul-Loader

### `Addmod_paragonScripts()` (`src/Paragon_loader.cpp`)
Ruft drei Sub-Loader:
- `AddParagonPlayerScripts()` — `ParagonPlayer` (PlayerScript) + `ParagonLifeLeech` (UnitScript) + `ParagonConfig` (WorldScript)
- `AddMyNPCScripts()` — `npc_paragon` CreatureScript (Gossip)
- (zusätzlich Cache-Init im WorldScript)

## Klassen-Übersicht

| Klasse | Typ | Zweck |
|--------|-----|-------|
| `ParagonPlayer` | `PlayerScript` | XP-Vergabe, Level-Up, Aura-Apply on Login/MapChange |
| `ParagonLifeLeech` | `UnitScript` | Implementiert Stat #17 (Life Leech) via `OnDamage` |
| `ParagonConfig` | `WorldScript` | `OnAfterConfigLoad` → 30+ `sConfigMgr->GetOption<>()` Calls |
| `npc_paragon` | `CreatureScript` | Gossip-Menu für NPC 900100 |

## XP-System

### XP-Quellen (alle pro Player im selben Map-Group-Member)

| Encounter-Typ | XP |
|---------------|----|
| Regular Elite | 1 |
| Dungeon Elite | 1 |
| Heroic Dungeon Elite | 2 |
| Dungeon Boss | 3 |
| Heroic Dungeon Boss | 5 |
| Raid Boss | 10 |
| World Boss | 20 |
| Daily/Weekly Quest | 3 |

### Level-Formel
`xpForLevel = 100 * pow(1.1, level-1)`. Wert wird in `character_paragon.xp` gespeichert und **zählt herunter** zu 0. Bei 0 → Level-Up, neue XP berechnet, `unspent_points += 5`.

Overflow-Schutz: `pow()` mit `int64`-Akkumulation, `std::min()` cap auf `INT32_MAX`. Bei `Paragon.MaxLevel > 0` und erreichtem Cap wird kein weiterer XP-Gewinn akzeptiert.

### Group-XP
`OnCreatureKill` iteriert Group-Members. Nur Mitglieder auf derselben Map zählen. PartyReduce-Faktor (`Paragon.PartyReduce`, Default 1.0) skaliert XP pro Member.

## In-Memory-Cache

```cpp
std::unordered_map<uint32 /*accountID*/, ParagonCache> _cache;
std::mutex _cacheMutex;

struct ParagonCache {
    uint32 level;
    uint32 xp;
    bool dirty;
};
```

- **Login** → SELECT, Cache befüllen.
- **MapChange** → liest aus Cache, kein DB-Call.
- **XP-Gain / Level-Up** → Cache aktualisieren, async DB-UPDATE.
- **Logout** → Cache invalidieren.

Mutex-Schutz bei jedem Zugriff. Bei mehreren Logins desselben Accounts (Multi-Box) wird Cache **nicht** dupliziert — alle Sessions teilen denselben Eintrag.

## Stat-Aura-System

### 17 Stats

| ID | Name | Aura-Klein | Aura-Groß | Skalierung |
|----|------|-----------|----------|-----------|
| 1 | Strength | 100001 | 100201 | groß = klein × 100 |
| 2 | Intellect | 100002 | 100202 | dito |
| 3 | Agility | 100003 | 100203 | dito |
| 4 | Spirit | 100004 | 100204 | dito |
| 5 | Stamina | 100005 | 100205 | dito |
| 6-16 | Haste, ArmorPen, SpellPower, Crit, MountSpeed, ManaRegen, Hit, Block, Expertise, Parry, Dodge | 100016-100026 | 100216-100226 | dito |
| 17 | Life Leech | 100027 | 100227 | dito |

Alle IDs **konfigurierbar** via `Paragon.Id<Stat>` und `Paragon.IdBig<Stat>`.

### Big+Small-Allocation

Aura-Stack-Limit ist `uint8` = 255. Workaround = Aura-Paar:

```
N = unspent points to allocate
big_stacks   = N / 100
small_stacks = N % 100
```

Beispiel: 666 Strength = 6×Big-Stack(à 500 Stat-Wert) + 66×Small-Stack(à 5) = 3330 effektiver Wert. Big-Auras haben in `spell_dbc` einen 100× größeren `BasePoints`-Wert.

### `RefreshParagonAura(Player*, uint32 const points[17])`

Datengetriebene Schleife:
```cpp
for (uint8 i = 0; i < 17; ++i) {
    uint32 pts = points[i];
    uint32 big = pts / 100;
    uint32 small = pts % 100;
    ApplyAuraStack(player, conf_AuraIds[i], small);
    ApplyAuraStack(player, conf_BigAuraIds[i], big);
}
```

Wo `ApplyAuraStack(player, auraId, n)`:
- `n == 0` → `player->RemoveAura(auraId);`
- `n > 0` → `player->AddAura(auraId, player); player->GetAura(auraId)->SetStackAmount(n);`

**Wichtig**: kein `RestoreHealth()` oder `RestoreMana()` mehr — der frühere Health/Mana-Exploit beim Aura-Refresh wurde behoben.

## NPC `npc_paragon` (CreatureScript, Entry 900100)

Gossip-Optionen:
1. **"Show Info"** — listet aktuelle Allokationen.
2. **"Reset Points"** — setzt alle 17 Spalten auf 0, refundet Punkte ins `unspent_points`-Feld, ruft `RefreshParagonAura` neu auf.

Greeting-Text-ID: `197760` (`npc_text`-Tabelle).

## Life Leech (`ParagonLifeLeech::OnDamage`)

```cpp
void OnDamage(Unit* attacker, Unit* victim, uint32& damage, SpellInfo const* spellInfo)
{
    Player* owner = attacker->GetCharmerOrOwnerPlayerOrPlayerItself();
    if (!owner) return;

    // Self-/Friendly-Damage-Check
    Player* victimOwner = victim->GetCharmerOrOwnerPlayerOrPlayerItself();
    if (victimOwner == owner) return;  // kein Self-Heal

    uint32 leechStacks = owner->GetAuraCount(conf_AuraIds[16])      // small
                       + owner->GetAuraCount(conf_BigAuraIds[16]) * 100; // big
    if (!leechStacks) return;

    float pct = leechStacks * conf_LifeLeechPct / 100.0f;
    int32 heal = static_cast<int32>(damage * pct);
    if (heal > 0)
        owner->HealBySpell(SpellHealInfo{owner, owner, /*spellId*/ 100027, uint32(heal)});
}
```

Funktioniert für:
- Player direct (Mage Fireball, Priest Smite, Warlock Shadow Bolt)
- Player Pet (Demonology Felguard, Frost Mage Water Elemental, BM Hunter Pets)
- Player Totem (alle Shaman-Specs)
- Charmed Unit (Mind Control, Frost DK Dancing Rune Weapon)

Schließt aus:
- Selbstschaden (Fall Damage, Environmental, eigene AoE-Splashes auf sich selbst)
- Friendly Fire auf eigene Pets/Totems

## AIO-Layer (Lua)

### Server-Handler (`Paragon_Server.lua`)

| Handler | Args | Wirkung |
|---------|------|---------|
| `RequestData` | — | sendet `categories`, `stats`, `allocations`, `unspent_points` an Client |
| `AllocatePoint` | `statId, amount` | clamped auf verfügbare Punkte + MaxStat; `UPDATE character_paragon_points`, `ApplyStatAuras` neu |
| `DeallocatePoint` | `statId, amount` | clamped auf aktuelle Allokation; verbucht Refund auf `unspent_points` |

### Client-UI (`Paragon_Client.lua`)

| Frame/Element | Zweck |
|---------------|-------|
| `ParagonFrame` | Hauptfenster (620×440, draggable, ESC-close) |
| Kategorie-Tabs (links) | Primary / Offensive / Defensive / Utility |
| `statRows[1..8]` | Icon, Name, Tooltip, "X/MAX"-Anzeige, +/- |
| +/- Buttons | Shift+Click = `amount=10`, sonst 1 |
| ESC-Menu-Button | Game-Menu-Eintrag "Paragon" |

### `Paragon_Data.lua`

- `Paragon.STATS[]` — 17 Einträge mit `id, name, category, icon, tooltip, auraId, bigAuraId, dbColumn`
- `Paragon.MAX_POINTS[]` — pro Stat, muss mit `mod_paragon.conf` synchron sein
- `Paragon.GetAllocations(characterID)` — DB-Query auf `character_paragon_points`
- Race/Gender-spezifische Sound-IDs für "Not enough money"-Voice

## Konfigurations-Optionen (Auszug)

| Schlüssel | Default | Wirkung |
|-----------|---------|---------|
| `Paragon.Enable` | true | Master-Toggle |
| `Paragon.MaxLevel` | 666 | 0 = unbegrenzt |
| `Paragon.MaxStr`-`Paragon.MaxLifeLeech` | 666 | Per-Stat-Cap (0 = unbegrenzt) |
| `Paragon.IdStr` | 100001 | Small-Aura-IDs |
| `Paragon.IdBigStr` | 100201 | Big-Aura-IDs (Default = small + 200) |
| `Paragon.LifeLeechPct` | 0.5 | % Heal per Stack |
| `Paragon.XpPerEliteRegular`-`Paragon.XpPerWorldBoss` | siehe Tabelle | XP-Belohnungen |
| `Paragon.PartyReduce` | 1.0 | Multiplikator für Group-XP |

## Bekannte Einschränkungen

- **SQL-Injection-Risiko in Lua**: `CharDBExecute` mit String-Concat (Eluna ohne PreparedStatements). Validierung im Server-Handler nötig.
- **C++ und Lua können kollidieren** — beide schreiben dieselbe DB-Tabelle. Aktuell konvergiert die Logik, aber Race-Conditions bei sehr schneller Allokation sind theoretisch möglich.
- **Anti-Farm-Maßnahmen fehlen** — keine Cooldowns auf XP-Quellen, keine Diminishing Returns bei wiederholten Kills derselben Mob-Entry.

## Test-Kommandos (für GMs)

```
.aura 100001    # Strength-Small applizieren (für Verifikation)
.aura 100201    # Strength-Big
.aura 100000    # Level-Counter
.npc add 900100 # Paragon-NPC spawnen
```
