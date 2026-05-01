# TODOs — mod-paragon

> Offene Aufgaben für dieses Modul. Erledigte TODOs in `log.md` festhalten und hier entfernen.

## Sicherheit

- [ ] **(mittel)** Race-Condition C++ ↔ Lua: beide Layer schreiben `character_paragon_points`. Bei sehr schneller Allokation theoretisch möglich. Optionen: Lua-Allocations über Handler an C++ delegieren (single source of truth), oder Row-Lock per Transaction.

## Doku

- [ ] **(hoch)** `CLAUDE.md` enthält eine "Known Issues"-Liste, die größtenteils erledigt ist (`~~strikethrough~~`). Phase B räumt das auf — verschoben in `log.md` (erledigt) oder hier (offen).

## Konvention

Erledigte Items NICHT durchstreichen — entfernen und in `log.md` dokumentieren.
