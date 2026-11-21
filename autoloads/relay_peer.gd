extends MultiplayerPeerExtension
## Online play through the relay server (server/relay/relay.js): a
## MultiplayerPeer that sends Godot's normal RPC packets over one WebSocket
## to the relay, which passes them to the other devices in the same room.
## The rest of the game can't tell the difference from LAN (ENet): the host
## is still peer 1 and decides everything.
##
##   var peer := RelayPeer.new()
##   peer.start_host(url)        -> room_ready(code) when the relay gives a code
##   peer.start_join(url, code)  -> peer_connected(1) when in the room
##   multiplayer.multiplayer_peer = peer
##
## Packets: [int32 LE target/sender][u8 channel][u8 transfer mode][payload].

signal room_ready(code: String)
## Something went wrong (bad code, server unreachable, host left...).
signal relay_failed(reason: String)

const OnlineConfig := preload("res://data/online_config.gd")
const HEADER := 6
const CONNECT_TIMEOUT := 75.0   # a sleeping free server can take ~1 minute to wake up

var code: String = ""
var last_reason: String = ""

var _ws := WebSocketPeer.new()
var _host := false
var _join_code := ""
var _id := 0
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _hello_sent := false
var _started_msec := 0
var _peers: Dictionary = {}        # remote peer id -> true
var _incoming: Array = []          # [sender, channel, mode, PackedByteArray]
var _target := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel := 0
var _refuse := false


func start_host(url: String) -> Error:
	_host = true
	_id = 1
	return _open(url)


func start_join(url: String, room_code: String) -> Error:
	_host = false
	_join_code = room_code.strip_edges().to_upper()
	_id = randi_range(2, 2147483647)
	return _open(url)


## Seconds since connecting started (the UI says "waking up the server"
## when it takes long).
func connecting_seconds() -> float:
	return (Time.get_ticks_msec() - _started_msec) / 1000.0


func _open(url: String) -> Error:
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	_ws.max_queued_packets = 8192
	var err := _ws.connect_to_url(url)
	if err != OK:
		last_reason = "Invalid online server address."
		return err
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	_started_msec = Time.get_ticks_msec()
	return OK


# ------------------------------------------------------------ polling
func _poll() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _hello_sent:
		_hello_sent = true
		var hello := {"op": "host" if _host else "join", "game": OnlineConfig.GAME_ID, "v": OnlineConfig.PROTOCOL}
		if not _host:
			hello["code"] = _join_code
			hello["id"] = _id
		_ws.send_text(JSON.stringify(hello))
	while _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		if _ws.was_string_packet():
			_on_control(pkt.get_string_from_utf8())
		elif pkt.size() >= HEADER:
			_incoming.append([pkt.decode_s32(0), pkt[4], pkt[5], pkt.slice(HEADER)])
	if _status == MultiplayerPeer.CONNECTION_CONNECTING and connecting_seconds() > CONNECT_TIMEOUT:
		_fail("Could not reach the online server. Check your internet connection.")
		_ws.close()
	if state == WebSocketPeer.STATE_CLOSED:
		if last_reason.is_empty():
			last_reason = "Could not reach the online server. Check your internet connection." \
				if _status == MultiplayerPeer.CONNECTION_CONNECTING else "Lost the connection to the online server."
			relay_failed.emit(last_reason)
		_drop_everyone()


func _on_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary) or not msg.has("op"):
		return
	match str(msg["op"]):
		"hosted":
			code = str(msg.get("code", ""))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			room_ready.emit(code)
		"joined":
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			_peers[1] = true
			peer_connected.emit(1)
		"peer_joined":
			var id := int(msg.get("id", 0))
			if id < 2:
				return
			if _refuse:
				_ws.send_text(JSON.stringify({"op": "kick", "id": id}))
				return
			_peers[id] = true
			peer_connected.emit(id)
		"peer_left":
			var id := int(msg.get("id", 0))
			if _peers.erase(id):
				peer_disconnected.emit(id)
		"error":
			_fail(str(msg.get("reason", "Online error.")))


func _fail(reason: String) -> void:
	if last_reason.is_empty():
		last_reason = reason
		relay_failed.emit(reason)


## Connection gone: tell Godot every remote peer left (a guest losing the
## host = "server disconnected"), then report disconnected.
func _drop_everyone() -> void:
	var was := _status
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	if was == MultiplayerPeer.CONNECTION_CONNECTED:
		for id in _peers.keys():
			peer_disconnected.emit(id)
	_peers.clear()
	_incoming.clear()


# ------------------------------------------------------------ packets
func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return _incoming.pop_front()[3]


func _get_packet_peer() -> int:
	return _incoming[0][0] if not _incoming.is_empty() else 0


func _get_packet_channel() -> int:
	return _incoming[0][1] if not _incoming.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _incoming[0][2] if not _incoming.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(HEADER)
	out.encode_s32(0, _target)
	out[4] = _channel
	out[5] = _mode
	out.append_array(buffer)
	return _ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func _get_max_packet_size() -> int:
	return 65536 - HEADER


# ------------------------------------------------------------ settings
func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _host


func _is_server_relay_supported() -> bool:
	return true


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _host:
		_ws.send_text(JSON.stringify({"op": "kick", "id": peer}))
		if _peers.erase(peer):
			peer_disconnected.emit(peer)
	elif peer == 1:
		_close()


func _close() -> void:
	_ws.close()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_peers.clear()
	_incoming.clear()
