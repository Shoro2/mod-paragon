# TODOs — mod-paragon

> Offene Aufgaben für dieses Modul. Erledigte TODOs in `log.md` festhalten und hier entfernen.

## Sicherheit

- [ ] **(mittel)** SQL-Injection-Risiko in Lua-Layer: `Paragon_Server.lua` nutzt `CharDBExecute` mit String-Concat (Eluna ohne Prepared Statements). Alle Handler-Args explizit validieren — speziell `statId` (Integer-Whitelist 1..17), `amount` (positive Integer mit Cap). Validation-Lib steht ab 2026-05 in `share-public/AIO_Server/Dep_Validation/validation.lua` zur Verfügung.

## Doku

- [ ] **(hoch)** `CLAUDE.md` enthält eine "Known Issues"-Liste, die größtenteils erledigt ist (`~~strikethrough~~`). Phase B räumt das auf — verschoben in `log.md` (erledigt) oder hier (offen).

## Konvention

Erledigte Items NICHT durchstreichen — entfernen und in `log.md` dokumentieren.
