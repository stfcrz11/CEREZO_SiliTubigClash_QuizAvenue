# Quiz Avenue relay (online play with room codes)

Players on different networks (home Wi-Fi, mobile data, school Wi-Fi) can't
connect to each other directly. With this small server running on the
internet, every phone connects **out** to it over a secure WebSocket
(`wss://`, port 443), and it passes the game's packets between the players
in the same room. The game's host still decides everything; the relay never
reads the packets.

- Host: PLAY → HOST GAME → **PLAY ONLINE** → a 5-letter room code appears.
- Friends: PLAY → JOIN GAME → type the code in **ONLINE ROOM CODE** → CONNECT.

The PLAY ONLINE button and the room-code box only appear once the game knows
the relay's address (`RELAY_URL` in `data/online_config.gd`).

## 1. Put the relay on the internet (free, about 10 minutes)

Any host that runs Node.js 18+ and allows WebSockets works. Example with
**Render** (free plan):

1. Push this repository to GitHub (the `render.yaml` at the repository root
   describes the service).
2. Sign in at https://render.com → **New** → **Blueprint** → pick this
   repository → **Apply**. (Or **New → Web Service**, root directory
   `server/relay`, build command `npm install`, start command `npm start`.)
3. When it is live, Render shows an address like
   `https://quiz-avenue-relay.onrender.com`. Opening it in a browser shows
   `ok 0 rooms`.

Free Render services sleep after ~15 minutes without use; the first
connection then takes up to a minute while it wakes up (the game says
"Waking up the online server..."). A paid plan or another host avoids this.

## 2. Tell the game the address

In `data/online_config.gd` set (note `wss://`, not `https://`):

```gdscript
const RELAY_URL := "wss://quiz-avenue-relay.onrender.com"
```

Export a new APK. Every player needs a build with the same address.

## Run it on your own PC (testing)

```
cd server/relay
npm install
npm start            # listens on port 8787 (set PORT to change)
```

Then start the game with the environment variable
`SILITUBIG_RELAY_URL=ws://127.0.0.1:8787` (no need to edit the config file).
Other devices on your network can use `ws://<your PC's IP>:8787`.

## Limits and safety

- Up to 500 rooms (`MAX_ROOMS` env var), 8 connections per room (the game
  allows 6 players), 64 KB per message, 400 messages per second per player.
- A connection must host or join within 15 s; dead connections are dropped
  by a ping every 20 s. When the host leaves, the room closes.
- Nothing is stored: no accounts, no logs of names or messages.
- Online and LAN play are separate: an online room can only be joined with
  its code.

## Protocol (must match `autoloads/relay_peer.gd`)

Text (JSON): `host` / `hosted{code,id}`, `join{code,id}` / `joined{id}`,
`peer_joined{id}`, `peer_left{id}`, `kick{id}` (host only),
`error{reason}`. Every hello carries `game: "silitubig-quizavenue"` and
`v: 1`. Binary: `[int32 LE target or sender][u8 channel][u8 mode][payload]`.
