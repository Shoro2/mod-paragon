# INDEX — mod-paragon

Einstiegspunkt für KI-Tools.

## Files in diesem Repo

| Datei | Größe | Zweck |
|-------|------:|-------|
| `INDEX.md` | <1 KB | diese Datei — Navigation |
| `CLAUDE.md` | ~5 KB | **Was** ist dieses Modul, welche Rolle, welche IDs/DB-Tabellen |
| `data_structure.md` | ~5 KB | Folder/File-Auflistung (Lua + C++ + SQL) |
| `functions.md` | ~8 KB | **Wie**: Aura-Refresh, XP-Logik, Big+Small-Pair-Mechanik, AIO-Handler, Konfig |
| `log.md` | ~2 KB | Commit-Log |
| `todo.md` | ~1 KB | offene Aufgaben |

## Cross-Repo

- Projekt-Übersicht: [`share-public/AI_GUIDE.md`](https://github.com/Shoro2/share-public/blob/main/AI_GUIDE.md)
- Cross-Repo-Historie: [`share-public/claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md)
- Custom-IDs Registry: [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md)
- AIO-Framework: [`share-public/docs/04-aio-framework.md`](https://github.com/Shoro2/share-public/blob/main/docs/04-aio-framework.md)
- DB-Extrakte (Spalten): [`share-public/mysqldbextracts/mysql_column_list_all.txt`](https://github.com/Shoro2/share-public/blob/main/mysqldbextracts/mysql_column_list_all.txt)

## Quick Facts

- Post-LV80 Account-XP-System mit 17 verteilbaren Stats
- Hybrid: C++ Aura-Layer + Lua/AIO-UI auf gleicher DB
- DB: 2 Tabellen in `acore_characters` (`character_paragon`, `character_paragon_points`)
- ~30 Konfig-Optionen in `mod_paragon.conf` (Aura-IDs, Max-Stats[17], Level-Cap, XP-Belohnungen)
- Liefert die Grundlage für `mod-paragon-itemgen` (welches den Paragon-Level liest, um Items zu enchanten)
