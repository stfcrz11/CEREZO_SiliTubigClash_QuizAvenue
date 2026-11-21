// Sili-Tubig: Quiz Avenue — online relay (room codes).
//
// Players on different networks can't reach each other directly (home
// routers and mobile data block incoming connections), so every device
// connects OUT to this small server over a WebSocket, and the server passes
// the game's packets between the devices in the same room. It never looks
// inside the packets: the game's host still decides everything.
//
//   host  -> {"op":"host", "game", "v"}            <- {"op":"hosted", "code", "id": 1}
//   guest -> {"op":"join", "game", "v", "code", "id"} <- {"op":"joined", "id"}
//   host  <- {"op":"peer_joined", "id"} / {"op":"peer_left", "id"}
//   host  -> {"op":"kick", "id"}       (room full / game already started)
//   any   <- {"op":"error", "reason"}  then the connection closes
//   data (binary): device -> server  [int32 LE target][u8 channel][u8 mode][payload]
//                  server -> device  [int32 LE sender][u8 channel][u8 mode][payload]
//                  target > 0: that peer, 0: everyone else, < 0: everyone but -target
//
// Run:  npm install  &&  npm start        (PORT env var, default 8787)
// GET / answers "ok" (health check for hosting services).

"use strict";

const http = require("http");
const crypto = require("crypto");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT) || 8787;
const GAME = "silitubig-quizavenue";
const PROTOCOL = 1;
const MAX_ROOMS = Number(process.env.MAX_ROOMS) || 500;
const MAX_PEERS_PER_ROOM = 8;          // the game itself allows 6; a little slack
const MAX_PACKET = 64 * 1024;          // bytes per message
const MAX_MSGS_PER_SEC = 400;          // per connection; 6 players x 30 updates/s fits easily
const HELLO_TIMEOUT_MS = 15000;        // must say host/join within this time
const PING_MS = 20000;                 // keep-alive (also stops idle proxies closing us)
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O, 1/I
const CODE_LEN = 5;

/** code -> { code, host: ws, peers: Map<id, ws>, created } */
const rooms = new Map();

function makeCode() {
  for (let tries = 0; tries < 50; tries++) {
    let code = "";
    const bytes = crypto.randomBytes(CODE_LEN);
    for (let i = 0; i < CODE_LEN; i++) code += CODE_CHARS[bytes[i] % CODE_CHARS.length];
    if (!rooms.has(code)) return code;
  }
  return null;
}

function sendJson(ws, obj) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function fail(ws, reason) {
  sendJson(ws, { op: "error", reason });
  setTimeout(() => ws.close(1000, "error"), 50);   // let the message go out first
}

/** Everyone in the room except the sender, by target rule. */
function targetsFor(room, senderId, target) {
  const all = [[1, room.host], ...room.peers.entries()];
  if (target > 0) return all.filter(([id]) => id === target && id !== senderId);
  if (target === 0) return all.filter(([id]) => id !== senderId);
  return all.filter(([id]) => id !== senderId && id !== -target);
}

function closeRoom(room, reason) {
  rooms.delete(room.code);
  for (const ws of room.peers.values()) fail(ws, reason);
  room.peers.clear();
}

function onHello(ws, msg) {
  if (msg.game !== GAME) return fail(ws, "This server is not for Sili-Tubig: Quiz Avenue.");
  if (msg.v !== PROTOCOL) return fail(ws, "Please update the game (online version mismatch).");
  if (msg.op === "host") {
    if (rooms.size >= MAX_ROOMS) return fail(ws, "The online server is full. Try again later.");
    const code = makeCode();
    if (!code) return fail(ws, "Could not make a room code. Try again.");
    const room = { code, host: ws, peers: new Map(), created: Date.now() };
    rooms.set(code, room);
    ws.room = room;
    ws.peerId = 1;
    sendJson(ws, { op: "hosted", code, id: 1 });
    return;
  }
  if (msg.op === "join") {
    const code = String(msg.code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    const room = rooms.get(code);
    if (!room) return fail(ws, "No game with that code. Check the code with the host.");
    if (room.peers.size + 1 >= MAX_PEERS_PER_ROOM) return fail(ws, "That game is full.");
    const id = Number(msg.id);
    if (!Number.isInteger(id) || id < 2 || id > 2147483647 || room.peers.has(id))
      return fail(ws, "Could not join. Please try again.");
    room.peers.set(id, ws);
    ws.room = room;
    ws.peerId = id;
    sendJson(ws, { op: "joined", id });
    sendJson(room.host, { op: "peer_joined", id });
    return;
  }
  fail(ws, "Unknown request.");
}

function onControl(ws, msg) {
  // after the hello, only the host may send control messages (kick)
  if (msg.op === "kick" && ws.peerId === 1 && ws.room) {
    const target = ws.room.peers.get(Number(msg.id));
    if (target) fail(target, "Could not join: the game is full or already started.");
  }
}

function onData(ws, buf) {
  const room = ws.room;
  if (!room || buf.length < 6) return;
  const target = buf.readInt32LE(0);
  const out = Buffer.from(buf);              // same layout, sender id in the first 4 bytes
  out.writeInt32LE(ws.peerId, 0);
  for (const [, peer] of targetsFor(room, ws.peerId, target)) {
    if (peer.readyState === peer.OPEN) peer.send(out, { binary: true });
  }
}

function onClose(ws) {
  const room = ws.room;
  if (!room) return;
  ws.room = null;
  if (ws.peerId === 1) {
    closeRoom(room, "The host left the game.");
  } else if (room.peers.get(ws.peerId) === ws) {
    room.peers.delete(ws.peerId);
    sendJson(room.host, { op: "peer_left", id: ws.peerId });
  }
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain" });
  res.end(`ok ${rooms.size} rooms\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_PACKET });

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.room = null;
  ws.peerId = 0;
  ws.msgWindow = Date.now();
  ws.msgCount = 0;
  const helloTimer = setTimeout(() => { if (!ws.room) fail(ws, "Timed out."); }, HELLO_TIMEOUT_MS);

  ws.on("pong", () => { ws.isAlive = true; });
  ws.on("message", (data, isBinary) => {
    const now = Date.now();
    if (now - ws.msgWindow >= 1000) { ws.msgWindow = now; ws.msgCount = 0; }
    if (++ws.msgCount > MAX_MSGS_PER_SEC) return ws.terminate();   // flooding
    if (isBinary) return onData(ws, data);
    let msg;
    try { msg = JSON.parse(data.toString()); } catch { return fail(ws, "Bad message."); }
    if (!msg || typeof msg.op !== "string") return fail(ws, "Bad message.");
    if (!ws.room) { clearTimeout(helloTimer); return onHello(ws, msg); }
    onControl(ws, msg);
  });
  ws.on("close", () => { clearTimeout(helloTimer); onClose(ws); });
  ws.on("error", () => {});
});

const pinger = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, PING_MS);
wss.on("close", () => clearInterval(pinger));

server.listen(PORT, () => console.log(`Quiz Avenue relay listening on port ${PORT}`));
