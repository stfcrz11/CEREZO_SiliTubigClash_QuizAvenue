extends "res://scenes/store_modal.gd"
## HOST A GAME window (scenes/host_modal.tscn): the IP on the chalkboard,
## the player slots and START GAME.
## PLAY ONLINE (shown when a relay server is set in data/online_config.gd)
## switches the chalkboard to a ROOM CODE that friends on any network type
## in JOIN GAME; USE WI-FI switches back to the LAN IP.
## To customize: open host_modal.tscn, click "HostModal" for the texts and
## colors in the Inspector, or click any node to change its look.

@export_group("Texts")
@export var ip_hint_text: String = "Everyone must be on the same Wi-Fi or phone hotspot."
@export var need_players_text: String = "Need %d+ players"     # %d = minimum players
@export var ready_text: String = "Ready!"
@export var online_hint_text: String = "Friends on any network type this code in JOIN GAME."
@export var connecting_text: String = "Connecting to the online server..."
@export var waking_text: String = "Waking up the online server (can take up to a minute)..."

const OnlineConfig := preload("res://data/online_config.gd")

var _online := false
var _mode_button: Button

@onready var ip_label: Label = $Center/Store/Body/Scroll/VBox/HostCard/VBox/IpLabel
@onready var ip_hint: Label = $Center/Store/Body/Scroll/VBox/HostCard/VBox/Hint
@onready var start_button: TextureButton = $Center/Store/Counter/VBox/Buttons/StartButton
@onready var caption: Label = $Center/Store/Body/Scroll/VBox/HostCard/VBox/Caption


func _ready() -> void:
	super()
	start_button.pressed.connect(func(): Network.start_game())
	_mode_button = PixelUI.button("PLAY ONLINE", "secondary", 64, 32)
	_mode_button.name = "ModeButton"
	_mode_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Center/Store/Body/Scroll/VBox/HostCard/VBox.add_child(_mode_button)
	_mode_button.pressed.connect(func():
		_online = not _online
		_start())
	Network.room_code_ready.connect(_on_room_code)
	Network.connection_failed.connect(_on_online_failed)


func open() -> void:
	visible = true
	_online = false
	_start()


## Hosts on the LAN or online, depending on the PLAY ONLINE switch.
func _start() -> void:
	_mode_button.visible = OnlineConfig.is_configured()
	_mode_button.text = "USE WI-FI" if _online else "PLAY ONLINE"
	start_button.disabled = true
	if _online:
		caption.text = "ROOM CODE"
		ip_label.text = "....."
		ip_hint.text = connecting_text
		if Network.host_online() != OK:
			_show_offline(Network.last_error)
			return
		_apply_layout()
		_set_status(connecting_text, waiting_color)
		return
	caption.text = "YOUR IP"
	if Network.host_game() != OK:
		ip_label.text = "Can't host"
		_set_status(Network.last_error, error_color)
		start_button.disabled = true
		return
	var ips := Network.local_ips()
	ip_label.text = ips[0] if not ips.is_empty() else "No network"
	ip_hint.text = ip_hint_text
	_apply_layout()


func _process(_delta: float) -> void:
	# a free relay server that was asleep takes a while to answer
	if visible and _online and Network.room_code.is_empty() and Network.relay_connecting_seconds() > 5.0:
		ip_hint.text = waking_text


func _on_room_code(code: String) -> void:
	if not visible or not _online:
		return
	ip_label.text = code
	ip_hint.text = online_hint_text
	_refresh_players()


func _on_online_failed(reason: String) -> void:
	if visible and _online:
		_show_offline(reason)


func _show_offline(reason: String) -> void:
	ip_label.text = "Offline"
	ip_hint.text = reason
	_set_status(reason, error_color)
	start_button.disabled = true


func _players_updated(count: int) -> void:
	if _online and Network.room_code.is_empty():
		return   # still connecting to the online server
	start_button.disabled = count < Network.MIN_PLAYERS
	if count < Network.MIN_PLAYERS:
		_set_status(need_players_text % Network.MIN_PLAYERS, waiting_color)
	else:
		_set_status(ready_text, good_color)


## IP chalkboard and players side by side on wide screens (phones in
## landscape, PC), one above the other on narrow ones.
func _layout_parts(m: Dictionary, content_width: float) -> void:
	var host_card: Control = $Center/Store/Body/Scroll/VBox/HostCard
	var wide := content_width >= 700.0
	body_box.vertical = not wide
	host_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_card.size_flags_stretch_ratio = 2.0
	players_card.size_flags_stretch_ratio = 3.0
	host_card.size_flags_vertical = Control.SIZE_FILL
	var caption: Label = $Center/Store/Body/Scroll/VBox/HostCard/VBox/Caption
	caption.add_theme_font_size_override("font_size", m["small"])
	ip_label.add_theme_font_size_override("font_size", m["big"])
	ip_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # a long IP wraps, never cut
	ip_hint.add_theme_font_size_override("font_size", m["hint"])
	ip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Center/Store/Body/Scroll/VBox/HostCard/VBox.add_theme_constant_override("separation", int(m["gap"] * 0.5))
	# the hint wraps inside the chalkboard: give the board a real width
	ip_hint.custom_minimum_size.x = 0.0
	_size_png_button(start_button, m["button"])
	if _mode_button:
		_mode_button.custom_minimum_size = Vector2(0, m["button"])
		_mode_button.add_theme_font_size_override("font_size", PixelUI.pixel_size_fit(32, "PLAY ONLINE", content_width * 0.4 - 40.0))
	# a room code reads best a little bigger than an IP
	if _online:
		ip_label.add_theme_font_size_override("font_size", int(m["big"] * 1.25))
