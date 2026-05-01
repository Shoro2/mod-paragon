# TODOs — mod-paragon

> Offene Aufgaben für dieses Modul. Erledigte TODOs in `log.md` festhalten und hier entfernen.

## Sicherheit

- [ ] **(mittel)** Race-Condition C++ ↔ Lua: beide Layer schreiben `character_paragon_points`. **Aktiv beobachtet, nicht nur theoretisch.** Lösung (User-Entscheidung 2026-05-01): Option (a) — Lua-Allokationen an C++ delegieren (Single Source of Truth) statt Row-Lock. Implementation in Bearbeitung.

## Code-Größe / Wartbarkeit

- [ ] **(mittel)** `src/ParagonPlayer.cpp` ist mit ~26 KB knapp am 25 K-Token-Lese-Limit für KI-Tools (`mcp__github__get_file_contents`). Splitten in thematisch fokussierte Files, z.B.:
  - `ParagonXP.cpp` — XP-Gewinn, Level-Up-Logik, Mob-Reward-Tabellen
  - `ParagonCache.cpp` / `ParagonCache.h` — In-Memory-Cache + Mutex
  - `ParagonAuras.cpp` — RefreshParagonAura, Big+Small-Pair-Logik
  - `ParagonConfig.cpp` — `OnAfterConfigLoad`-Hook + alle `conf_*`-Variablen
  - `ParagonLifeLeech.cpp` — `UnitScript::OnDamage` für Life-Leech
  - `ParagonPlayer.cpp` (slim) — nur PlayerScript-Hooks, delegate auf die anderen
  - Erlaubt Tools, einzelne Aspekte zu inspizieren, ohne den ganzen Monolith zu reissen. Nach M2-Fix einplanen, da der M2-Fix sowieso Änderungen an `ParagonPlayer.cpp` macht.

## Doku

- [ ] **(hoch)** `CLAUDE.md` enthält eine "Known Issues"-Liste, die größtenteils erledigt ist (`~~strikethrough~~`). Phase B räumt das auf — verschoben in `log.md` (erledigt) oder hier (offen).

## Konvention

Erledigte Items NICHT durchstreichen — entfernen und in `log.md` dokumentieren.
