# Change Log — mod-paragon

> Minimal commit log. One line per change with a reference to the commit.

## 2026

- 2026-05-27 — refactor(Paragon): apply stats via direct core APIs instead of stacking auras — fixes the 255-stack cap, the relog/over-time stat loss (auras were saved to `character_aura`), and broken Life Leech, all at the root. Each stat is applied once with its full `int32` value (`HandleStatFlatModifier`/`ApplyRatingMod`/`ApplySpellPowerBonus`/`ApplyManaRegenBonus`; Mount Speed via single non-stacking aura 100029). Lua casts trigger spell 100028 (`spell_paragon_reapply`) after the DB write; C++ is now the single source of truth. Life Leech read from an in-memory snapshot. Removed `paragon_big_stat_spells.sql` + the lifeleech dummy; added cleanup migrations for `spell_dbc` and `character_aura`. NPC reset is now race-free. Added `GetParagonLevel()` for >255 level reads.
- 2026-05-01 — fix(Paragon/C++): soft-recover paragon mismatch instead of destructive reset ([8222889](https://github.com/Shoro2/mod-paragon/commit/822288970327deb89a200746d225afc28675e6cf)) — M2 part 3/3: `ApplyParagonStatEffects()` no longer zeroes stats; only `unspent_points` is corrected on a mismatch.
- 2026-05-01 — fix(Paragon/Lua): use atomic update in Allocate/DeallocatePoint ([f856c7b](https://github.com/Shoro2/mod-paragon/commit/f856c7b472c4bfae9996e4d8f1058d775e86ad9b)) — M2 part 2/3: replaced two async updates with a single synchronous one.
- 2026-05-01 — fix(Paragon/Lua): add atomic UpdateAllocationAndUnspent ([8d8ec2d](https://github.com/Shoro2/mod-paragon/commit/8d8ec2d2876d87a24009577fa83d566a37fcf198)) — M2 part 1/3: new `Paragon.UpdateAllocationAndUnspent` function (synchronous CharDBQuery for stat+unspent in one UPDATE).
- 2026-04-28 — fix(Core): trigger Life Leech for caster pets, totems and charm damage ([eb7fea3](https://github.com/Shoro2/mod-paragon/commit/eb7fea35d4f56faf4862f406220fe215c15a5dd8)) — Resolve via `GetCharmerOrOwnerPlayerOrPlayerItself()`; victim-owner check guards against self-heal from self damage.
- 2026-04-28 — style(Core): fix codestyle violations blocking CI ([ad6e15d](https://github.com/Shoro2/mod-paragon/commit/ad6e15dde249c4726b742c4968d77b878b0b6a03)) — `GetCounter()` → `ToString()` in logs, removed double blank lines.
- 2026-04-28 — fix(Core): resolve pre-existing -Werror build failures ([ea808d2](https://github.com/Shoro2/mod-paragon/commit/ea808d22f7005dea38c710bd366dc9787e882875)) — removed unused `memberCount`; added `OnGossipSelect override` specifier.
- 2026-03-23 — feat(Core): add Big-stat aura IDs to mod_paragon.conf.dist ([1200622](https://github.com/Shoro2/mod-paragon/commit/1200622c82e8ee7b77ab9c219664bc43de46722a)) — added 17 missing `Paragon.IdBig*` keys; default = small+200.
- 2026-03-22 — feat(Core): set max paragon level to 666 and align config max stats to 666 ([1461750](https://github.com/Shoro2/mod-paragon/commit/1461750b5019d73a12d8ce9af39ad8fb3dbfc573)) — all `Paragon.Max*` from 255 → 666.
- 2026-03-22 — feat(Core): big+small spell pairs for stats above 255 stacks ([4ef8c53](https://github.com/Shoro2/mod-paragon/commit/4ef8c53613459fdf9535a12ed0ab60300dc9cd28)) — bypass uint8 stack limit via aura pairs (100×/stack + 1×/stack); new SQL `paragon_big_stat_spells.sql` (IDs 100201-100227).

## Convention

Append new entries at the top. Detailed descriptions belong in the commit body or in `share-public/claude_log.md`.
