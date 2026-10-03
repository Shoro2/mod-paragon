# Character deletion regression fixtures

These tests use a **private MySQL instance**, never the workbench or production.
Only synthetic TBOT00 / TBOT01 / CRTEST1 account identifiers are seeded; no
account or character data is imported. All commands below ran on the Windows
operator box on 2026-10-03. The vault's MIG-068 owns current deployment status.

The SQL runner checks the actual scratch `@@datadir` before any write, refuses
port 3306, and creates a fresh PID-suffixed fixture database. The native setup
also checks the datadir and refuses an existing `paragon_delete_native` schema.
The native executable is fixed to loopback port 13368 and that schema.

```powershell
$task = 'C:\wowstuff\ForgottenLand2.0\tools\paragon-delete-01a1038b'
$python = 'C:\Users\Anwender\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
& $python "$task\core\modules\mod-paragon\tests\test_character_deletion.py" --mysql $mysql --port 13368 --scratch-datadir "$task\mysql-data" --core "$task\core"
```

The private server was initialized with `mysqld --no-defaults
--initialize-insecure --datadir=<private directory>` and started hidden with
`--no-defaults --port=13368 --bind-address=127.0.0.1 --mysqlx=OFF
--skip-log-bin --datadir=<same directory>`. Keep its log/PID file in the same
private directory; never start, stop or modify a shared MySQL service for this test.

The SQL fixtures reproduce the original orphan/duplicate-insert bug, then check
permanent deletion and GUID reuse, soft deletion/restoration, unrelated rows,
last-character account progress, missing allocations, explicit rollback,
transaction failure, migration rollback/idempotence and fresh-install file order.
They execute the prepared SQL extracted from the actual core source and the
unchanged migration file. The Python source-contract check is static evidence.

For the **native** test, create an isolated core worktree containing only this
module, configure with `SCRIPTS=none`, `MODULES=static`, `TOOLS_BUILD=none`,
`WITH_WARNINGS=1`, and an unused private install prefix. Build `worldserver`.
Temporarily append this line to the isolated core's top-level CMakeLists.txt:

```cmake
include(modules/mod-paragon/tests/native_fixture.cmake)
```

```powershell
cmake -S "$task\core" -B "$task\build"
cmake --build "$task\build" --config RelWithDebInfo --target paragon_delete_native --parallel 4
& $python "$task\core\modules\mod-paragon\tests\prepare_native_fixture.py" --mysql $mysql --scratch-datadir "$task\mysql-data" --core "$task\core"
& "$task\build\bin\RelWithDebInfo\paragon_delete_native.exe" "$task\mysql-data\" "$task\paragon-enabled.conf" "$task\paragon-disabled.conf"
```

Supply full configs made from core `worldserver.conf.dist` plus module
`mod_paragon.conf.dist`, with `Paragon.Enable = 1` / `0` respectively. The native
test initializes the real configuration cache, real ScriptMgr registration,
real CharacterDatabase prepared statements and real asynchronous worker.
It calls **`Player::DeleteFromDB` itself**. A second fixture-only hook appends
a duplicate-account INSERT after Paragon cleanup to force the actual core
transaction to fail; both core character and allocation must survive rollback.
The single async worker plus a `DO 1` barrier waits for preceding deletion work.
No listener, world data, client, live account or mod-fl-testbots is used.

The private executable directory needs `libmysql.dll` from the installed MySQL
8.4 `lib/` and `libcrypto-3-x64.dll` / `libssl-3-x64.dll` from the configured
OpenSSL `bin/`. Copy dependencies there only. Remove the temporary CMake include
before committing; it is not a production target.

Evidence: `fixture-tests.log`, `native-tests.log`, `configure.log`, `build.log`
and `native-build.log` in the private task directory. Native passes mean offline
core verification, **not a booted server or in-game test**. A minimal-module
Windows build does not prove the production module fleet or Ubuntu toolchain.
