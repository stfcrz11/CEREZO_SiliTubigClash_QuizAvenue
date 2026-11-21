extends RefCounted
## Online play (room codes) settings.
##
## RELAY_URL is the address of the relay server in server/relay/ once it is
## running on the internet, for example "wss://quiz-avenue-relay.onrender.com".
## Use wss:// (secure) for a hosted server; ws:// only works for a server on
## your own PC or network (testing).
## While it is empty, the PLAY ONLINE and room-code buttons explain that
## online play is not set up yet. LAN play never needs it.
##
## For testing without editing this file, start the game with the
## environment variable SILITUBIG_RELAY_URL (e.g. ws://127.0.0.1:8787).

const RELAY_URL := ""

## Must match GAME / PROTOCOL in server/relay/relay.js.
const GAME_ID := "silitubig-quizavenue"
const PROTOCOL := 1


static func relay_url() -> String:
	var env := OS.get_environment("SILITUBIG_RELAY_URL").strip_edges()
	return env if not env.is_empty() else RELAY_URL


static func is_configured() -> bool:
	return not relay_url().is_empty()
