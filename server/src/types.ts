export interface Room {
  code: string;
  name: string;
  hostName: string;
  hostAddress: string;
  port: number;
  map?: string;
  mode?: string;
  playerCount: number;
  maxPlayers: number;
  createdAt: number;
  lastHeartbeat: number;
  isDedicated: boolean;
  pid?: number;
}

export interface Player {
  id: number;
  name: string;
  isHost: boolean;
  joinedAt: number;
}

export interface WebSocketClientData {
  peerId: number;
  roomCode: string;
  playerName: string;
  isHost: boolean;
}

export type WsMessageType =
  | "join"
  | "leave"
  | "chat"
  | "ready"
  | "room_update"
  | "peer_joined"
  | "peer_left"
  | "ping"
  | "pong"
  | "welcome"
  | "error";

export interface WsMessage {
  type: WsMessageType;
  [key: string]: any;
}
