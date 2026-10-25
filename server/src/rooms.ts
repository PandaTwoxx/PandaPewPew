import type { Room } from "./types";
import { spawn } from "child_process";

// Maps and modes the game server knows (see scripts/map_defs.gd and
// scripts/mode_defs.gd). Dedicated servers spawned through the API accept
// these values and pass them to the Godot server as --map/--mode args.
const VALID_MAPS = ["farm", "orchard", "corral"];
const VALID_MODES = ["kills", "ctf", "conquest"];

export class RoomManager {
  private rooms: Map<string, Room> = new Map();
  private nextDedicatedPort = 7800;

  constructor() {
    // Periodic cleanup of stale rooms (heartbeat > 40s ago)
    setInterval(() => this.cleanupStaleRooms(), 15000);
  }

  public generateCode(): string {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    for (let attempts = 0; attempts < 100; attempts++) {
      let code = "";
      for (let i = 0; i < 4; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
      }
      if (!this.rooms.has(code)) {
        return code;
      }
    }
    return `R${Date.now().toString(36).slice(-3).toUpperCase()}`;
  }

  public createRoom(options: {
    code?: string;
    name?: string;
    hostName?: string;
    hostAddress?: string;
    port?: number;
    maxPlayers?: number;
    isDedicated?: boolean;
    pid?: number;
    map?: string;
    mode?: string;
  }): Room {
    const code = (options.code || this.generateCode()).toUpperCase().trim();
    const now = Date.now();

    const room: Room = {
      code,
      name: options.name || `Arena ${code}`,
      hostName: options.hostName || "Host",
      hostAddress: options.hostAddress || "127.0.0.1",
      port: options.port || 7777,
      playerCount: 1,
      maxPlayers: options.maxPlayers || 32,
      createdAt: now,
      lastHeartbeat: now,
      isDedicated: options.isDedicated || false,
      pid: options.pid,
      map: options.map,
      mode: options.mode,
    };

    this.rooms.set(code, room);
    console.log(`[RoomManager] Created room ${code} ("${room.name}") on port ${room.port}`);
    return room;
  }

  public getRoom(code: string): Room | undefined {
    return this.rooms.get(code.toUpperCase().trim());
  }

  public getAllRooms(): Room[] {
    return Array.from(this.rooms.values()).sort((a, b) => b.createdAt - a.createdAt);
  }

  public removeRoom(code: string): boolean {
    const norm = code.toUpperCase().trim();
    const room = this.rooms.get(norm);
    if (!room) return false;

    if (room.pid) {
      try {
        process.kill(room.pid);
        console.log(`[RoomManager] Killed dedicated server process ${room.pid} for room ${norm}`);
      } catch (e) {
        // process may have already exited
      }
    }

    this.rooms.delete(norm);
    console.log(`[RoomManager] Removed room ${norm}`);
    return true;
  }

  public heartbeat(code: string, playerCount?: number): boolean {
    const room = this.getRoom(code);
    if (!room) return false;
    room.lastHeartbeat = Date.now();
    if (typeof playerCount === "number") {
      room.playerCount = Math.max(1, playerCount);
    }
    return true;
  }

  public spawnDedicatedRoom(options: {
    name?: string;
    maxPlayers?: number;
    map?: string;
    mode?: string;
    hostAddress?: string;
  }): Room {
    const code = this.generateCode();
    const port = this.nextDedicatedPort++;
    if (this.nextDedicatedPort > 7999) {
      this.nextDedicatedPort = 7800;
    }

    // Only forward map/mode values the game actually knows; anything else
    // falls back to the server's own defaults (farm / kills).
    const map = VALID_MAPS.includes(options.map || "") ? options.map : undefined;
    const mode = VALID_MODES.includes(options.mode || "") ? options.mode : undefined;
    const args = ["--headless", "--path", ".", "--", "--server", `--port=${port}`];
    if (map) args.push(`--map=${map}`);
    if (mode) args.push(`--mode=${mode}`);

    // The address clients use to reach this game server. In a container the
    // loopback default is wrong for remote players, so prefer an explicit
    // PUBLIC_HOST env var, then the address the caller used for the request.
    const hostAddress =
      options.hostAddress || process.env.PUBLIC_HOST || "127.0.0.1";

    const proc = spawn("godot", args, {
      cwd: process.cwd(),
      detached: false,
      stdio: "ignore",
    });

    const room = this.createRoom({
      code,
      name: options.name || `Dedicated ${code}`,
      hostName: "Dedicated Server",
      hostAddress,
      port,
      maxPlayers: options.maxPlayers || 32,
      isDedicated: true,
      pid: proc.pid,
      map,
      mode,
    });

    proc.on("error", (err) => {
      console.log(`[RoomManager] Failed to start dedicated server ${code}: ${err}`);
      this.rooms.delete(code);
    });

    proc.on("exit", (exitCode) => {
      console.log(`[RoomManager] Dedicated server ${code} (pid ${proc.pid}) exited with code ${exitCode}`);
      this.rooms.delete(code);
    });

    return room;
  }

  private isProcessAlive(pid: number): boolean {
    try {
      process.kill(pid, 0);
      return true;
    } catch (e: any) {
      // EPERM means the process exists but we cannot signal it; ESRCH means gone.
      return e?.code === "EPERM";
    }
  }

  private cleanupStaleRooms(): void {
    const now = Date.now();
    for (const [code, room] of this.rooms.entries()) {
      // Dedicated servers have no client sending heartbeats, so a stale
      // timestamp must not kill a live game: refresh while the process runs,
      // and only reap it once the process is actually gone.
      if (room.isDedicated && room.pid && this.isProcessAlive(room.pid)) {
        room.lastHeartbeat = now;
        continue;
      }
      if (now - room.lastHeartbeat > 45000) {
        console.log(`[RoomManager] Room ${code} timed out, cleaning up.`);
        this.removeRoom(code);
      }
    }
  }
}
