# INDEX — mod-paragon

Entry point for AI tools.

## Files in this repo

| File | Size | Purpose |
|-------|------:|-------|
| `INDEX.md` | <1 KB | this file — navigation |
| `CLAUDE.md` | ~5 KB | **What** this module is, what role, which IDs/DB tables |
| `data_structure.md` | ~5 KB | Folder/file listing (Lua + C++ + SQL) |
| `functions.md` | ~8 KB | **How**: stat application (direct core APIs), XP logic, AIO handlers, config |
| `log.md` | ~2 KB | Commit log |
| `todo.md` | ~1 KB | open tasks |

## Cross-Repo

- Project overview: [`share-public/AI_GUIDE.md`](https://github.com/Shoro2/share-public/blob/main/AI_GUIDE.md)
- Cross-repo history: [`share-public/claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md)
- Custom IDs registry: [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md)
- AIO framework: [`share-public/docs/04-aio-framework.md`](https://github.com/Shoro2/share-public/blob/main/docs/04-aio-framework.md)
- DB extracts (columns): [`share-public/mysqldbextracts/mysql_column_list_all.txt`](https://github.com/Shoro2/share-public/blob/main/mysqldbextracts/mysql_column_list_all.txt)

## Quick Facts

- Post-LV80 account XP system with 17 distributable stats
- C++ applies stats via direct core APIs (single source of truth); Lua/AIO is the allocation UI
- DB: 2 tables in `acore_characters` (`character_paragon`, `character_paragon_points`)
- Config in `mod_paragon.conf` (level/mount-speed spell IDs, max stats[17], level cap 666, XP rewards, LifeLeechPct)
- Provides the foundation for `mod-paragon-itemgen` (which reads the Paragon level to enchant items)
