extends "res://scenes/store_modal.gd"
## HOST A GAME window (scenes/host_modal.tscn): the IP on the chalkboard,
## the player slots and START GAME.
## To customize: open host_modal.tscn, click "HostModal" for the texts and
## colors in the Inspector, or click any node to change its look.

@export_group("Texts")
@export var ip_hint_text: String = "Everyone must be on the same Wi-Fi or phone hotspot."
@export var need_players_text: String = "Need %d+ players"     # %d = minimum players
@export var ready_text: String = "Ready!"

@onready var ip_label: Label = $Center/Store/Body/Scroll/VBox/HostCard/VBox/IpLabel
@onready var ip_hint: Label = $Center/Store/Body/Scroll/VBox/HostCard/VBox/Hint
@onready var start_button: TextureButton = $Center/Store/Counter/VBox/Buttons/StartButton


func _ready() -> void:
	super()
	start_button.pressed.connect(func(): Network.start_game())


func open() -> void:
	visible = true
	if Network.host_game() != OK:
		ip_label.text = "Can't host"
		_set_status(Network.last_error, error_color)
		start_button.disabled = true
		return
	var ips := Network.local_ips()
	ip_label.text = ips[0] if not ips.is_empty() else "No network"
	ip_hint.text = ip_hint_text
	_refresh_players()


func _players_updated(count: int) -> void:
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
