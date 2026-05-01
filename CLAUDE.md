# mod-paragon

> Lies zuerst [`INDEX.md`](./INDEX.md). Mechanik & Hooks: [`functions.md`](./functions.md). Folder-Layout: [`data_structure.md`](./data_structure.md). Offenes: [`todo.md`](./todo.md). Commit-Spur: [`log.md`](./log.md).

## Was ist das Modul?

AzerothCore-Modul für **WoW 3.3.5a (WotLK)**. Implementiert ein **Post-Level-80-Progressionssystem** ("Paragon"): Charaktere, die das normale WotLK-Levelcap erreicht haben, sammeln aus Kreaturen-Kills, Quests und Bossen weitere Erfahrungspunkte und erhalten pro Paragon-Level 5 Punkte, die sie auf 17 Stats verteilen können (Strength, Intellect, Agility, Spirit, Stamina, Haste, ArmorPen, SpellPower, Crit, MountSpeed, ManaRegen, Hit, Block, Expertise, Parry, Dodge, **LifeLeech**).

**Account-weit**: Level + XP geteilt über alle Charaktere des Accounts.
**Per Charakter**: die Stat-Verteilung — jeder Charakter wählt eigene Schwerpunkte.

## Rolle im Gesamtprojekt

```
Player Kill / Quest Complete
       │
       ▼ XP-Gain (mod-paragon)
       │
       ▼ Level-Up → 5 unspent_points → Player verteilt via UI
       │
       ▼ character_paragon_points → invisible Stack-Auras (100xxx) auf Player
       │
       ▼ Wert wird gelesen von mod-paragon-itemgen
                 (skaliert Item-Bonus-Stats: amount = ceil(level × scaling × quality))
```

mod-paragon ist die **Grundlage** für mod-paragon-itemgen. Ohne mod-paragon hat ein Character keinen Paragon-Level → mod-paragon-itemgen würde keine Bonus-Stats anwenden (`MinParagonLevel`-Check).

## Custom-Daten

| Typ | Eintrag | Bemerkung |
|-----|--------|-----------|
| **DB-Tabelle (acore_characters)** | `character_paragon` | Account-Level/XP (PK `accountID`, `level`, `xp` zählt **runter** zu 0) |
| | `character_paragon_points` | Per-Char Stat-Allocation (`unspent_points` + 17 Stat-Spalten) |
| **Custom-Spells** | 100000 (Level-Counter), 100001-100005 (Str/Int/Agi/Spi/Sta), 100016-100027 (alle Combat-Ratings + LifeLeech) | siehe [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md) |
| | 100201-100227 | "Big"-Counterparts für Stats > 255 (Stack ×100) |
| **Custom-NPC** | `npc_paragon` (Entry **900100**) | Gossip-Menü für Info / Reset |
| **AIO-Handler-Namen** | `Paragon` (Server) / `Paragon_Client` (Client) | Details: [`functions.md`](./functions.md#aio-handler) |
| **Slash-Commands** | (keine) | UI öffnet sich über NPC oder ESC-Menü-Button |
| **Custom-Items** | keine — Paragon-Punkte sind **DB-Wert** (`unspent_points`), kein Item |

## XP-Quellen (Top-Level)

| Encounter-Typ | XP |
|---------------|----|
| Regular/Dungeon Elite | 1 |
| Heroic Dungeon Elite | 2 |
| Dungeon Boss | 3 |
| Heroic Dungeon Boss | 5 |
| Raid Boss | 10 |
| World Boss | 20 |
| Daily/Weekly Quest | 3 |

Group-Kills geben XP an alle Group-Members auf derselben Map. Level-Formel: `100 × 1.1^(level-1)` XP, zählt **herunter** zu 0.

## Konfiguration (Top-Level)

`conf/mod_paragon.conf.dist` — ~30 Optionen:

- Master-Toggle: `Paragon.Enable`
- Level-Cap: `Paragon.MaxLevel` (0 = unbegrenzt)
- Aura-IDs: `Paragon.IdStr`, `Paragon.IdInt`, …, `Paragon.IdLifeLeech` (alle individuell überschreibbar)
- Max-Punkte pro Stat: `Paragon.MaxStr`, `Paragon.MaxInt`, … (Default 255 je, 0 = unbegrenzt)
- XP-Belohnungen: `Paragon.XpEliteDungeon`, `Paragon.XpRaidBoss`, …
- Party-XP-Reduce: `Paragon.PartyReducePct`
- LifeLeech-%: `Paragon.LifeLeechPct = 0.5` (Default)

Vollständige Liste mit Defaults: [`functions.md`](./functions.md#konfiguration).

## Was das Modul **nicht** tut

- **kein** Item-Enchanting → das macht das eigenständige `mod-paragon-itemgen`
- **keine** Talente / Specs → Paragon-Stats sind reine numerische Boni
- **kein** PvP-Toggle (Stats wirken in PvP wie in PvE)
- **kein** Anti-Farm-Schutz (siehe [`todo.md`](./todo.md))

## Hinweise zur Architektur

- **Hybrid C++/Lua**: Beide Layer schreiben in `character_paragon_points`. C++ ist die Single-Source-of-Truth für Aura-Anwendung; Lua/AIO ist die UI für Allokation. Race-Conditions theoretisch möglich, in der Praxis durch UI-Latenz selten — siehe [`todo.md`](./todo.md).
- **Stack-Limit-Workaround**: WoW-Auras stacken bis 255. Für Stats > 255 gibt es paarige "Big"-Auras (Stack × 100) und "Small"-Auras (Stack × 1). Allokation `N`: `big = N/100`, `small = N%100`.
- **LifeLeech (100027)**: heilt einen konfigurierbaren Prozentsatz des verursachten Schadens. Funktioniert auch über Pets/Totems via `Unit::GetCharmerOrOwnerPlayerOrPlayerItself()`.

## Lizenz

GPL v2.
