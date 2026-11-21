extends "res://scenes/store_modal.gd"
## JOIN A GAME window (scenes/join_modal.tscn): games found nearby, the
## type-an-IP box, and after connecting the player slots.
## To customize: open join_modal.tscn, click "JoinModal" for the texts and
## colors in the Inspector, or click any node to change its look.
## FoundList/GameTemplate is ONE found game: the game copies it.
## ONLINE ROOM CODE box (made from a copy of the IP box, shown when a relay
## server is set in data/online_config.gd): join a friend on any network.

@export_group("Texts")
@export var join_hint_text: String = "Pick a game or type an IP"
@export var connecting_text: String = "Connecting..."
@export var connected_text: String = "Connected! Waiting for host..."
@export var type_ip_text: String = "Type an IP first"
@export var no_games_text: String = "No games yet"
@export var game_name_text: String = "%s's game"              # %s = host's name

var connected: bool = false
var _dots_time: float = 0.0
var _kb_shift: float = 0.0      # how far the window is moved up for the phone keyboard
var code_card: Control          # ONLINE ROOM CODE box
var code_edit: LineEdit

const OnlineConfig := preload("res://data/online_config.gd")
const WAKING_TEXT := "Waking up the online server (can take up to a minute)..."

@onready var find_card: Control = $Center/Store/Body/Scroll/VBox/FindCard
@onready var searching: Label = $Center/Store/Body/Scroll/VBox/FindCard/VBox/Header/Searching
@onready var found_list: VBoxContainer = $Center/Store/Body/Scroll/VBox/FindCard/VBox/FoundList
@onready var game_template: Control = $Center/Store/Body/Scroll/VBox/FindCard/VBox/FoundList/GameTemplate
@onready var ip_card: Control = $Center/Store/Body/Scroll/VBox/IpCard
@onready var ip_edit: LineEdit = $Center/Store/Body/Scroll/VBox/IpCard/VBox/IpRow/IpEdit


func _ready() -> void:
	super()
	game_template.visible = false   # the template is copied, never shown
	$Center/Store/Body/Scroll/VBox/IpCard/VBox/IpRow/ConnectButton.pressed.connect(func(): _connect_to(ip_edit.text))
	ip_edit.text_submitted.connect(_connect_to)
	# phones: a number pad with a "." key (digits and periods for an IP)
	ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_make_code_card()
	Network.connected_to_host.connect(_on_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.hosts_found_changed.connect(_refresh_found)


func open() -> void:
	connected = false
	Network.leave()
	Network.start_listening()
	_show_parts()
	_set_status("Pick a game, or type a room code or IP" if OnlineConfig.is_configured() else join_hint_text, hint_color)
	_refresh_found()


## The ONLINE ROOM CODE box: a copy of the IP box placed above it.
func _make_code_card() -> void:
	code_card = ip_card.duplicate()
	code_card.name = "CodeCard"
	body_box.add_child(code_card)
	body_box.move_child(code_card, ip_card.get_index())
	code_card.get_node("VBox/Label").text = "ONLINE ROOM CODE (any network)"
	code_edit = code_card.get_node("VBox/IpRow/IpEdit")
	code_edit.name = "CodeEdit"
	code_edit.placeholder_text = "e.g. K7PQ2"
	code_edit.max_length = 8
	code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	code_edit.text_changed.connect(func(t: String):
		# codes are capital letters / digits: type in any case
		var up := t.to_upper()
		if up != t:
			var caret := code_edit.caret_column
			code_edit.text = up
			code_edit.caret_column = caret)
	code_edit.text_submitted.connect(_join_code)
	code_card.get_node("VBox/IpRow/ConnectButton").pressed.connect(func(): _join_code(code_edit.text))
	for edit in [ip_edit, code_edit]:
		edit.focus_entered.connect(func(): body_scroll.ensure_control_visible.call_deferred(edit.get_parent()))


func _join_code(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.is_empty():
		_set_status("Type a room code first", error_color)
		return
	_set_status("Connecting to the online server...", waiting_color)
	if Network.join_online(code) != OK:
		_set_status(Network.last_error, error_color)


func _show_parts() -> void:
	# before connecting: games list + code box + IP box. After: the player slots.
	find_card.visible = not connected
	ip_card.visible = not connected
	code_card.visible = not connected and OnlineConfig.is_configured()
	players_card.visible = connected
	visible = true


func _awning() -> String:
	return "blue"


## Games list and IP box one above the other; rows and the IP box big
## enough to tap.
func _layout_parts(m: Dictionary, _content_width: float) -> void:
	body_box.vertical = true
	$Center/Store/Body/Scroll/VBox/FindCard/VBox/Header/Label.add_theme_font_size_override("font_size", m["body"])
	searching.add_theme_font_size_override("font_size", m["hint"])
	found_list.custom_minimum_size.y = m["row"]
	found_list.add_theme_constant_override("separation", int(m["gap"] * 0.75))
	game_template.custom_minimum_size.y = m["row"]
	game_template.get_node("HBox/Texts/Name").add_theme_font_size_override("font_size", m["body"])
	game_template.get_node("HBox/Texts/Info").add_theme_font_size_override("font_size", m["small"])
	_size_png_button(game_template.get_node("HBox/JoinButton"), m["button"])
	for card in [ip_card, code_card]:
		card.get_node("VBox/Label").add_theme_font_size_override("font_size", m["body"])
		card.get_node("VBox/IpRow").add_theme_constant_override("separation", int(m["gap"]))
		var edit: LineEdit = card.get_node("VBox/IpRow").get_child(0)
		edit.custom_minimum_size.y = maxf(72.0, roundf(m["vh"] * 72.0 / 640.0))
		edit.add_theme_font_size_override("font_size", m["body"] + 4)
		_size_png_button(card.get_node("VBox/IpRow/ConnectButton"), m["button"])
	_refresh_found()   # row copies pick up the new sizes


func _process(delta: float) -> void:
	if visible and find_card.visible:
		_dots_time += delta
		searching.text = "Searching" + ".".repeat(1 + int(_dots_time * 2.0) % 3)
	if visible:
		_follow_keyboard(delta)
		if not connected and Network.relay_connecting_seconds() > 5.0 and status.text != WAKING_TEXT:
			_set_status(WAKING_TEXT, waiting_color)


## Phones: when the on-screen keyboard is up, slide the window up just
## enough that the IP box and CONNECT stay above it; slide back after.
func _follow_keyboard(delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and _kb_shift == 0.0:
		return   # PC: no on-screen keyboard (asking would only log warnings)
	var kb_px := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		kb_px = float(DisplayServer.virtual_keyboard_get_height())
	var target := 0.0
	var focused: LineEdit = ip_edit if ip_edit.has_focus() else (code_edit if code_edit.has_focus() else null)
	if kb_px > 0.0 and focused and focused.is_visible_in_tree():
		var vp := get_viewport()
		var kb := kb_px / UiScale.content_scale(vp)          # screen pixels -> UI units
		var row: Control = focused.get_parent()
		var bottom := row.get_global_rect().end.y + _kb_shift  # where it is without the shift
		var free_bottom := vp.get_visible_rect().size.y - kb - 12.0
		target = clampf(bottom - free_bottom, 0.0, store.get_global_rect().position.y + _kb_shift)
	_kb_shift = lerpf(_kb_shift, target, minf(1.0, delta * 14.0))
	if absf(_kb_shift - target) < 0.5:
		_kb_shift = target
	# shift both offsets (moving `position` would freeze the size)
	var insets := UiScale.safe_insets(get_viewport())
	$Center.offset_top = insets["top"] - _kb_shift
	$Center.offset_bottom = -insets["bottom"] - _kb_shift


func _connect_to(ip: String) -> void:
	ip = ip.strip_edges()
	if ip.is_empty():
		_set_status(type_ip_text, error_color)
		return
	_set_status(connecting_text, waiting_color)
	if Network.join_game(ip) != OK:
		_set_status(Network.last_error, error_color)


func _on_connection_failed(reason: String) -> void:
	if visible:
		_set_status(reason, error_color)


func _on_connected() -> void:
	if not visible:
		return
	Network.stop_listening()
	connected = true
	_show_parts()
	_set_status(connected_text, good_color)
	_refresh_players()


func _refresh_found() -> void:
	if not visible or connected:
		return
	_clear(found_list, game_template)
	if Network.found_hosts.is_empty():
		var empty := Label.new()
		empty.text = no_games_text
		empty.add_theme_color_override("font_color", hint_color)
		empty.add_theme_font_size_override("font_size", _m.get("hint", 14))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		found_list.add_child(empty)
	else:
		for id in Network.found_hosts:
			var info: Dictionary = Network.found_hosts[id]
			found_list.add_child(_game_row(info["ip"], info))


func _game_row(ip: String, info: Dictionary) -> Control:
	# a copy of FoundList/GameTemplate filled in for one found game
	var row := game_template.duplicate()
	row.visible = true
	var host_name: String = info.get("name", "")
	var full: bool = info["players"] >= Network.MAX_PLAYERS
	row.get_node("HBox/Texts/Name").text = (game_name_text % host_name) if not host_name.is_empty() else ip
	row.get_node("HBox/Texts/Info").text = "%d/%d%s" % [info["players"], Network.MAX_PLAYERS, "  FULL" if full else ""]
	var join: TextureButton = row.get_node("HBox/JoinButton")
	join.disabled = full
	join.pressed.connect(_connect_to.bind(ip))
	# the whole row is tappable (not only JOIN); a drag still scrolls the list
	if not full:
		row.gui_input.connect(_on_row_input.bind(ip))
	return row


var _row_press := Vector2.INF

func _on_row_input(event: InputEvent, ip: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_row_press = event.global_position
		elif _row_press != Vector2.INF and event.global_position.distance_to(_row_press) < 16.0:
			_row_press = Vector2.INF
			_connect_to(ip)
