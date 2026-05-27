# TODOs — mod-paragon

> Open tasks for this module. Record completed TODOs in `log.md` and remove them here.

## Security

- [ ] **(low)** SQL injection in the Lua layer is now mitigated: `statId` is a whitelisted `STAT_BY_ID` lookup, `amount` is `tonumber`-coerced, `dbColumn` comes only from `Paragon.STATS`, and all interpolated numerics in `Paragon_Data.lua` are wrapped in `tonumber()`. Remaining (optional, defense-in-depth): adopt `share-public/AIO_Server/Dep_Validation/validation.lua` for centralized handler-arg validation.

## Docs

- [ ] **(high)** `CLAUDE.md` contains a "Known Issues" list that is largely resolved (`~~strikethrough~~`). Phase B will clean this up — moved into `log.md` (resolved) or here (open).

## Convention

Do NOT cross out completed items — remove them and document them in `log.md`.
