# PandaPewPew

2D top-down multiplayer shooter base (Godot 4, GDScript, ENet).

- Run the project, then **Host**, or **Join** with an IP/port (default 7777).
- Dedicated server: `godot --headless --path . -- --server --port=7777` (up to 32 clients).
- Controls: WASD move, mouse aim, hold left click to shoot, Esc leaves.

Design: owner-authoritative movement (synced via MultiplayerSynchronizer); server-authoritative
shooting, bullets, damage and respawn. Players and bullets are replicated with MultiplayerSpawner.

Known gaps: no scoreboard, health isn't sent to late joiners, no lag compensation or client prediction.
