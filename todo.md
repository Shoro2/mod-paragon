# TODOs — mod-paragon

> Open tasks for this module. Record completed TODOs in `log.md` and remove them here.

## Security

- [ ] **(medium)** SQL injection risk in the Lua layer: `Paragon_Server.lua` uses `CharDBExecute` with string concatenation (Eluna without prepared statements). Validate all handler args explicitly — particularly `statId` (integer whitelist 1..17), `amount` (positive integer with cap). The validation lib is available since 2026-05 in `share-public/AIO_Server/Dep_Validation/validation.lua`.

## Docs

- [ ] **(high)** `CLAUDE.md` contains a "Known Issues" list that is largely resolved (`~~strikethrough~~`). Phase B will clean this up — moved into `log.md` (resolved) or here (open).

## Convention

Do NOT cross out completed items — remove them and document them in `log.md`.
