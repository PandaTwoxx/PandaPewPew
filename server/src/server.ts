import { RoomManager } from "./rooms";
import type { WebSocketClientData, WsMessage } from "./types";
import type { ServerWebSocket } from "bun";

const PORT = parseInt(process.env.PORT || "3000", 10);
const roomManager = new RoomManager();

// Track active WebSocket connections per room code
const roomSockets = new Map<string, Set<ServerWebSocket<WebSocketClientData>>>();
let nextPeerId = 2; // Peer ID 1 is reserved for Host

function getCorsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

function jsonResponse(data: any, status: number = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...getCorsHeaders(),
    },
  });
}

function broadcastToRoom(
  roomCode: string,
  message: WsMessage,
  senderWs?: ServerWebSocket<WebSocketClientData>
) {
  const sockets = roomSockets.get(roomCode.toUpperCase());
  if (!sockets) return;
  const payload = JSON.stringify(message);
  for (const ws of sockets) {
    if (ws !== senderWs && ws.readyState === 1) {
      ws.send(payload);
    }
  }
}

const server = Bun.serve<WebSocketClientData>({
  port: PORT,
  fetch(req, server) {
    const url = new URL(req.url);

    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response(null, { headers: getCorsHeaders() });
    }

    // Upgrade WebSocket connections
    if (url.pathname === "/ws") {
      const roomCode = (url.searchParams.get("room") || "").toUpperCase();
      const playerName = url.searchParams.get("name") || "Player";
      const isHost = url.searchParams.get("host") === "true";
      const peerId = isHost ? 1 : nextPeerId++;

      const upgraded = server.upgrade(req, {
        data: {
          peerId,
          roomCode,
          playerName,
          isHost,
        },
      });

      if (upgraded) return undefined;
      return jsonResponse({ error: "WebSocket upgrade failed" }, 400);
    }

    // Health check
    if (url.pathname === "/health" || url.pathname === "/api/health") {
      const rooms = roomManager.getAllRooms();
      return jsonResponse({
        status: "ok",
        uptime: process.uptime(),
        roomsCount: rooms.length,
        totalPlayers: rooms.reduce((sum, r) => sum + r.playerCount, 0),
        timestamp: Date.now(),
      });
    }

    // List all active rooms
    if (url.pathname === "/api/rooms" && req.method === "GET") {
      return jsonResponse({
        success: true,
        rooms: roomManager.getAllRooms(),
      });
    }

    // Create / Register a room
    if (url.pathname === "/api/rooms" && req.method === "POST") {
      return req.json().then((body: any) => {
        const clientIp = server.requestIP(req)?.address || "127.0.0.1";
        const room = roomManager.createRoom({
          code: body.code,
          name: body.name,
          hostName: body.hostName,
          hostAddress: body.hostAddress || clientIp,
          port: body.port,
          maxPlayers: body.maxPlayers,
        });
        return jsonResponse({ success: true, room }, 201);
      }).catch((err) => {
        return jsonResponse({ success: false, error: "Invalid JSON body" }, 400);
      });
    }

    // Spawn dedicated server room
    if (url.pathname === "/api/rooms/dedicated" && req.method === "POST") {
      // Advertise the address the caller used to reach this backend (the
      // game server runs on the same host), unless PUBLIC_HOST overrides it.
      // This is what makes dedicated rooms joinable by remote players instead
      // of pointing them at 127.0.0.1.
      const spawnWith = (body: any) => {
        const hostHeader = req.headers.get("host") || "";
        const hostFromHeader = hostHeader.startsWith("[")
          ? hostHeader.slice(1, hostHeader.indexOf("]"))
          : hostHeader.split(":")[0];
        return roomManager.spawnDedicatedRoom({
          name: body?.name,
          maxPlayers: body?.maxPlayers,
          map: body?.map,
          mode: body?.mode,
          hostAddress: process.env.PUBLIC_HOST || hostFromHeader || undefined,
        });
      };
      return req.json().then((body: any) => {
        const room = spawnWith(body);
        return jsonResponse({ success: true, room }, 201);
      }).catch(() => {
        const room = spawnWith({});
        return jsonResponse({ success: true, room }, 201);
      });
    }

    // Lookup room by code
    const roomMatch = url.pathname.match(/^\/api\/rooms\/([A-Za-z0-9]+)$/);
    if (roomMatch) {
      const code = roomMatch[1].toUpperCase();

      if (req.method === "GET") {
        const room = roomManager.getRoom(code);
        if (!room) {
          return jsonResponse({ success: false, error: "Room not found" }, 404);
        }
        return jsonResponse({ success: true, room });
      }

      if (req.method === "DELETE") {
        const removed = roomManager.removeRoom(code);
        return jsonResponse({ success: removed });
      }
    }

    // Heartbeat for room
    const heartbeatMatch = url.pathname.match(/^\/api\/rooms\/([A-Za-z0-9]+)\/heartbeat$/);
    if (heartbeatMatch && req.method === "POST") {
      const code = heartbeatMatch[1].toUpperCase();
      return req.json().then((body: any) => {
        const ok = roomManager.heartbeat(code, body.playerCount);
        return jsonResponse({ success: ok });
      }).catch(() => {
        const ok = roomManager.heartbeat(code);
        return jsonResponse({ success: ok });
      });
    }

    return jsonResponse({ error: "Endpoint not found" }, 404);
  },

  websocket: {
    open(ws) {
      const { roomCode, peerId, playerName, isHost } = ws.data;
      if (!roomCode) return;

      if (!roomSockets.has(roomCode)) {
        roomSockets.set(roomCode, new Set());
      }
      roomSockets.get(roomCode)!.add(ws);

      console.log(`[WS] ${playerName} (Peer #${peerId}) connected to room [${roomCode}]`);

      // Welcome message to client
      ws.send(JSON.stringify({
        type: "welcome",
        peerId,
        roomCode,
        isHost,
        timestamp: Date.now(),
      }));

      // Broadcast to room
      broadcastToRoom(roomCode, {
        type: "peer_joined",
        peerId,
        playerName,
        isHost,
      }, ws);

      // Update room manager player count
      const sockets = roomSockets.get(roomCode);
      if (sockets) {
        roomManager.heartbeat(roomCode, sockets.size);
      }
    },

    message(ws, rawMsg) {
      const { roomCode, peerId, playerName } = ws.data;
      if (!roomCode) return;

      try {
        const data = typeof rawMsg === "string" ? JSON.parse(rawMsg) : JSON.parse(new TextDecoder().decode(rawMsg));

        if (data.type === "ping") {
          ws.send(JSON.stringify({ type: "pong", timestamp: Date.now() }));
          return;
        }

        if (data.type === "chat") {
          broadcastToRoom(roomCode, {
            type: "chat",
            peerId,
            playerName,
            text: data.text,
            timestamp: Date.now(),
          });
          return;
        }

        // Generic event broadcast to room
        broadcastToRoom(roomCode, {
          ...data,
          senderPeerId: peerId,
          senderName: playerName,
        }, ws);

      } catch (e) {
        console.error("[WS] Error parsing message:", e);
      }
    },

    close(ws) {
      const { roomCode, peerId, playerName, isHost } = ws.data;
      if (!roomCode) return;

      const sockets = roomSockets.get(roomCode);
      if (sockets) {
        sockets.delete(ws);
        if (sockets.size === 0) {
          roomSockets.delete(roomCode);
        } else {
          roomManager.heartbeat(roomCode, sockets.size);
        }
      }

      console.log(`[WS] ${playerName} (Peer #${peerId}) left room [${roomCode}]`);

      broadcastToRoom(roomCode, {
        type: "peer_left",
        peerId,
        playerName,
        isHost,
      });

      // If host disconnected from non-dedicated room, unregister room after grace period
      if (isHost) {
        const room = roomManager.getRoom(roomCode);
        if (room && !room.isDedicated) {
          console.log(`[WS] Host disconnected from room [${roomCode}], removing.`);
          roomManager.removeRoom(roomCode);
        }
      }
    },
  },
});

console.log(`
╔════════════════════════════════════════════════════════════════╗
║  🐼 PandaPewPew Multiplayer Backend (Bun.js) v1.0.0            ║
║  🚀 Server listening on http://localhost:${server.port}               ║
║  📡 WebSocket Hub ready on ws://localhost:${server.port}/ws          ║
║  🌾 Matchmaking & Room Orchestrator ACTIVE                     ║
╚════════════════════════════════════════════════════════════════╝
`);
