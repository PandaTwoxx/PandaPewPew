# PandaPewPew

2D top-down multiplayer shooter base (Godot 4, GDScript, ENet).

- Run the project, then **Host**, or **Join** with an IP/port (default 7777).
- Pick the **map** and **mode** in the Host panel. Clients are told by the server on join.
- Dedicated server: `godot --headless --path . -- --server --port=7777 --map=farm --mode=kills` (up to 32 clients).
- Controls: WASD move, mouse aim, hold left click to shoot (10s firing round, then 5s gun cooldown), hold Tab for the scoreboard, Esc leaves.

Maps (`scripts/map_defs.gd`): `farm`, `orchard`, `corral`.
Modes (`scripts/mode_defs.gd`, rules in `scripts/modes/`):
- `kills` - free-for-all, first to 15 kills (5 min limit).
- `ctf` - Red vs Blue, 3 captures (8 min limit). Dropped flags return after 15s or on a teammate's touch.
- `conquest` - Red vs Blue, hold points for 1 score/s each, first to 200 (8 min limit).

Dead players respawn after 3s at the team spawn farthest from enemies, with 2s of spawn protection. Matches
restart automatically 8s after a result. No friendly fire in team modes.

Adding a map: add an entry to `map_defs.gd` (props, spawns, flag bases, points) and to `ORDER`.
Adding a mode: subclass `scripts/modes/game_mode.gd` and register it in `mode_defs.gd`.

Design: owner-authoritative movement (synced via MultiplayerSynchronizer); server-authoritative
shooting, bullets, damage, respawn and mode rules. Players and bullets are replicated with MultiplayerSpawner.
Per-player state (health, team, alive, kills, deaths, flag) rides a server-owned `StateSync` on each player, and
match state (timer, scores, flags, points) is the server-owned `MatchState` node, so late joiners get it all.

Known gaps: player positions are client-trusted (flag pickups/captures use them), no lag compensation or client
prediction, no map rotation between matches, no player names.
