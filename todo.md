# TODOs — mod-paragon

> Open tasks for this module. Record completed TODOs in `log.md` and remove them here.

## Security

- [ ] **(low)** Input validation is wired in: `Paragon_Server.lua` validates `statId` (`Validate.IsIntInRange` 1..#STATS) and `amount` (`Validate.IsPositiveInt`, cap 666) via the shared `share-public/AIO_Server/Dep_Validation/validation.lua`, with a permissive shim fallback + warning if the lib is not deployed. `dbColumn` is whitelisted from `Paragon.STATS` and numerics in `Paragon_Data.lua` are `tonumber`-coerced. **Deploy reminder**: copy `Dep_Validation/` to `lua_scripts/` so the strict (non-shim) checks run.

## Docs

- [ ] **(high)** `CLAUDE.md` contains a "Known Issues" list that is largely resolved (`~~strikethrough~~`). Phase B will clean this up — moved into `log.md` (resolved) or here (open).

## Convention

Do NOT cross out completed items — remove them and document them in `log.md`.
