# PandaPewPew Multiplayer Backend (Bun.js)

High-performance WebSocket & HTTP multiplayer backend and room orchestrator for **PandaPewPew**, built with [Bun](https://bun.sh).

## Features

- **🚀 Ultra-Fast HTTP REST API**: Room listings, 4-letter room code generation, heartbeats, and health monitoring.
- **📡 WebSocket Room Hub (`/ws`)**: Real-time lobby state, peer join/leave events, ping/pong latency checks, and lobby chat.
- **🎮 Headless Dedicated Server Orchestrator**: Automatically spawns and supervises Godot dedicated server instances (`--headless -- --server`) on demand with dynamic port allocation (ports 7800-7999).
- **⏱️ Auto-Cleanup**: Reaps inactive or abandoned lobbies automatically when heartbeats lapse.

## Quick Start

### 1. Install Dependencies
```bash
bun install
```

### 2. Run the Server
```bash
# Start in production mode
bun run start

# Or with live reload in development mode
bun run dev
```

The server listens on `http://localhost:3000` (configurable via `PORT` environment variable).

## API Endpoints

### HTTP REST

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` or `/api/health` | Service uptime, active room count, total players connected |
| `GET` | `/api/rooms` | List all active public lobbies |
| `POST` | `/api/rooms` | Register/create a new room with host info & port |
| `GET` | `/api/rooms/:code` | Look up a room by its 4-character code (e.g. `PAND`) |
| `POST` | `/api/rooms/:code/heartbeat` | Send host keepalive and update player count |
| `POST` | `/api/rooms/dedicated` | Spawn a new headless Godot dedicated server process |
| `DELETE` | `/api/rooms/:code` | Close and unregister a room |

### WebSocket Hub

Connect to `ws://localhost:3000/ws?room=<ROOM_CODE>&name=<PLAYER_NAME>&host=<true|false>`:
- **Welcome Packet**: `{ "type": "welcome", "peerId": 1, "roomCode": "FARM", "isHost": true }`
- **Peer Joined**: `{ "type": "peer_joined", "peerId": 2, "playerName": "Alice" }`
- **Peer Left**: `{ "type": "peer_left", "peerId": 2, "playerName": "Alice" }`
- **Lobby Chat**: `{ "type": "chat", "text": "Ready to brawl!" }`
- **Ping / Pong**: `{ "type": "ping" }` -> `{ "type": "pong", "timestamp": ... }`
