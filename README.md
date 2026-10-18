# PandaPewPew

2D top-down multiplayer shooter base (Godot 4, GDScript, ENet & Bun.js).

- **Multiplayer Modes**:
  - **Online Rooms (Bun.js)**: Create or join rooms via 4-character codes (e.g. `FARM`, `PAND`), or browse active lobbies.
  - **Direct LAN / IP**: Host or join directly with IP and port (default 7777).
- **Bun.js Multiplayer Backend**:
  - Start backend: `cd server && bun install && bun run start` (runs on `http://localhost:3000`).
  - Supports room matchmaking, live WebSocket lobby sync (`/ws`), and automated headless server spawning.
- **Dedicated Server**: `godot --headless --path . -- --server --port=7777` (up to 32 clients), or click **Launch Dedicated** in the Bun lobby.
- **Controls**: WASD move, mouse aim, hold left click to shoot (10s firing round, then 5s gun cooldown), Esc leaves.

Design: owner-authoritative movement (synced via MultiplayerSynchronizer); server-authoritative
shooting, bullets, damage and respawn. Players and bullets are replicated with MultiplayerSpawner.

Known gaps: no scoreboard, health isn't sent to late joiners, no lag compensation or client prediction.
