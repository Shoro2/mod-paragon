# Change Log — mod-paragon

> Minimaler Commit-Log. Eine Zeile pro Änderung mit Verweis auf den Commit.

## 2026

- 2026-04-28 — fix(Core): trigger Life Leech for caster pets, totems and charm damage ([eb7fea3](https://github.com/Shoro2/mod-paragon/commit/eb7fea35d4f56faf4862f406220fe215c15a5dd8)) — Resolve via `GetCharmerOrOwnerPlayerOrPlayerItself()`; victim-owner-check gegen Self-Heal aus Selbstschaden.
- 2026-04-28 — style(Core): fix codestyle violations blocking CI ([ad6e15d](https://github.com/Shoro2/mod-paragon/commit/ad6e15dde249c4726b742c4968d77b878b0b6a03)) — `GetCounter()` → `ToString()` in Logs, doppelte Leerzeilen entfernt.
- 2026-04-28 — fix(Core): resolve pre-existing -Werror build failures ([ea808d2](https://github.com/Shoro2/mod-paragon/commit/ea808d22f7005dea38c710bd366dc9787e882875)) — `memberCount` ungenutzt entfernt; `OnGossipSelect override` Spezifizierer ergänzt.
- 2026-03-23 — feat(Core): add Big-stat aura IDs to mod_paragon.conf.dist ([1200622](https://github.com/Shoro2/mod-paragon/commit/1200622c82e8ee7b77ab9c219664bc43de46722a)) — 17 fehlende `Paragon.IdBig*`-Keys ergänzt; Default = small+200.
- 2026-03-22 — feat(Core): set max paragon level to 666 and align config max stats to 666 ([1461750](https://github.com/Shoro2/mod-paragon/commit/1461750b5019d73a12d8ce9af39ad8fb3dbfc573)) — alle `Paragon.Max*` von 255 → 666.
- 2026-03-22 — feat(Core): big+small spell pairs for stats above 255 stacks ([4ef8c53](https://github.com/Shoro2/mod-paragon/commit/4ef8c53613459fdf9535a12ed0ab60300dc9cd28)) — uint8-Stack-Limit umgangen via Aura-Paaren (100×/Stack + 1×/Stack); neue SQL `paragon_big_stat_spells.sql` (IDs 100201-100227).

## Konvention

Neue Einträge oben anhängen. Detail-Beschreibungen gehören in den Commit-Body bzw. `share-public/claude_log.md`.
