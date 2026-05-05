# mod-paragon

Post-level-80 progression system ("Paragon") for an [AzerothCore](https://www.azerothcore.org/) **WoW 3.3.5a (WotLK)** server.

## What it does

Once a character reaches the regular level cap (80), they keep gaining experience points from creature kills, quests, and bosses. Each Paragon level grants 5 unspent points the player can distribute across **17 stats**:

- **Primary stats**: Strength, Intellect, Agility, Spirit, Stamina
- **Combat ratings**: Haste, Crit, Hit, Expertise, Block, Parry, Dodge, ArmorPen
- **Magic**: SpellPower, ManaRegen
- **Mobility**: MountSpeed
- **Special**: LifeLeech (heals a configurable percentage of damage dealt — also works through pets, totems, and charmed units)

Paragon level and XP are **account-wide** (shared across all characters of the account). The stat allocation is **per character**, so each alt can pick its own focus.

## Key features

- Post-80 XP from creature kills, quests, and bosses, with configurable rewards per encounter type (regular vs. heroic dungeon, raid boss, world boss, daily quest, …)
- Group-aware XP: kills on the same map credit all group members
- Stat caps per stat (default 255 each, configurable, 0 = unlimited)
- Stack-aura "big + small" workaround for stats above 255 (transparent to the player)
- In-game UI via custom NPC (`npc_paragon`, entry `900100`) **and** ESC-menu button — no slash commands needed
- DB-backed state in `acore_characters` (`character_paragon`, `character_paragon_points`)
- Full server↔client UI via the [AIO framework](https://github.com/Rochet2/AIO)

## Installation

1. Place this module inside the AzerothCore `modules/` directory:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Shoro2/mod-paragon.git
   ```
2. Re-run CMake and build the server:
   ```bash
   cd ../build
   cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DSCRIPTS=static -DMODULES=static
   make -j$(nproc) && make install
   ```
3. Apply the SQL files shipped under `data/sql/db-characters/` and `data/sql/db-world/` (the AzerothCore SQL updater picks them up automatically when the module is enabled).
4. Copy the config and adjust if needed:
   ```bash
   cp $HOME/azeroth-server/etc/mod_paragon.conf.dist $HOME/azeroth-server/etc/mod_paragon.conf
   ```
5. The client side requires the [AIO addon](https://github.com/Rochet2/AIO) installed in `Interface/AddOns/`. The Paragon UI ships with this module's `Paragon_System_LUA/` directory and is delivered to the client by AIO automatically.
6. Restart the world server. Verify with the in-game NPC or the ESC-menu Paragon button.

## Configuration (excerpt)

`conf/mod_paragon.conf.dist` — about 30 options, including:

- `Paragon.Enable` — master toggle
- `Paragon.MaxLevel` (0 = unlimited)
- XP rewards: `Paragon.XpEliteDungeon`, `Paragon.XpRaidBoss`, …
- Stat caps: `Paragon.MaxStr`, `Paragon.MaxInt`, …
- `Paragon.LifeLeechPct` (default `0.5`%)
- `Paragon.PartyReducePct`

## Requirements

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) (WoW 3.3.5a / WotLK)
- [AIO framework](https://github.com/Rochet2/AIO) (for the in-game UI)

## Project context

Part of a multi-repo project. The companion module [mod-paragon-itemgen](https://github.com/Shoro2/mod-paragon-itemgen) reads the Paragon level to scale automatic bonus-stat enchantments on freshly looted/crafted items. Cross-cutting documentation lives in [share-public](https://github.com/Shoro2/share-public).

## License

GPL v2 (see `LICENSE`).
