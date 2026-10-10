# Online relay server

Online matches use rollback netcode: each player's device runs the deterministic simulation
(`sim/`), and only input packets travel over the network. The server is therefore a tiny relay
(`server/relay.gd`) that pairs two players by room code and forwards their packets. It needs
almost no CPU or bandwidth (about 60 small JSON messages per second per player).

## Run locally

```bash
"D:/election world fight/tools/godot-portable/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://server/relay_main.gd -- --port 9080
```

Then open the game twice (two windows or two devices on the same network), choose
**ONLINE · BETA**, keep the server `ws://localhost:9080` (or `ws://<your-PC-IP>:9080`), and enter
the same room code on both.

## Host it for the public site

The Pages site is served over HTTPS, so browsers only allow a **secure** WebSocket (`wss://`).
Pick any host that runs a Docker container and gives you HTTPS:

- Fly.io, Render, Railway, Google Cloud Run (WebSockets enabled), or a small VPS with Caddy.

1. Build the image from the repo root: `docker build -f server/Dockerfile -t wfc-relay .`
2. Deploy it. The host sets `PORT`; the relay reads it.
3. Put the public address in `data/site_config.json` as `"relay_url": "wss://your-relay.example.com"`.
4. Push to `main`; the Pages build ships the new URL and the lobby uses it by default.

Decisions for the owner: which host (free tiers are fine for testing), and whether to add
matchmaking (random opponents) and accounts later (planned with Nakama; see the master plan).

## Tests

- `tests/test_rollback.gd`: rollback sessions under latency, jitter and packet loss.
- `tests/test_online_relay.gd`: two WebSocket clients through the relay on localhost.
- `tests/test_online_battle.gd`: two full battle scenes play each other through the relay.
