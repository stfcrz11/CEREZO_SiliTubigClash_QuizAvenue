extends Control
## Shared parts of the two sari-sari store windows (host_modal.tscn and
## join_modal.tscn): the player slots, the status line on the counter, and
## closing with the ✕ / CANCEL / Esc. Each window adds its own parts in
## host_modal.gd / join_modal.gd.
## Slots/SlotTemplate in each scene is ONE player slot: the game copies it,
## so edit it in the editor to change how every slot looks.
## Size and look on every screen: _apply_layout() (sizes come from the
## viewport height through scenes/pixel_store.gd, the shared store window;
## the roof is built there from tiled pieces so it fits any width).

const PixelStore := preload("res://scenes/pixel_store.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const UiScale := preload("res://scenes/ui_scale.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")

@export_group("Texts")
@export var open_slot_text: String = "Open slot"

@export_group("Colors")
@export var slot_colors: Array[Color] = [Color(0.98, 0.82, 0.3), Color(0.35, 0.75, 1.0), Color(0.5, 0.9, 0.55),
	Color(0.9, 0.55, 1.0), Color(1.0, 0.6, 0.4), Color(0.6, 0.95, 0.95)]
@export var hint_color: Color = Color(0.7, 0.74, 0.82)
@export var error_color: Color = Color(1.0, 0.5, 0.45)
@export var good_color: Color = Color(0.5, 0.95, 0.55)
@export var waiting_color: Color = Color(1.0, 0.85, 0.4)

@onready var players_card: Control = $Center/Store/Body/Scroll/VBox/PlayersCard
@onready var count_label: Label = $Center/Store/Body/Scroll/VBox/PlayersCard/VBox/Header/Count
@onready var sili_chip: Label = $Center/Store/Body/Scroll/VBox/PlayersCard/VBox/Header/SiliChip
@onready var tubig_chip: Label = $Center/Store/Body/Scroll/VBox/PlayersCard/VBox/Header/TubigChip
@onready var slots: GridContainer = $Center/Store/Body/Scroll/VBox/PlayersCard/VBox/Slots
@onready var slot_template: Control = $Center/Store/Body/Scroll/VBox/PlayersCard/VBox/Slots/SlotTemplate
@onready var status: Label = $Center/Store/Counter/VBox/Status
@onready var store: VBoxContainer = $Center/Store
@onready var body_scroll: ScrollContainer = $Center/Store/Body/Scroll
@onready var body_box: BoxContainer = $Center/Store/Body/Scroll/VBox
@onready var cancel_button: TextureButton = $Center/Store/Counter/VBox/Buttons/CancelButton

var _top_parts: Dictionary = {}
var _m: Dictionary = {}          # last PixelStore.metrics()


func _ready() -> void:
	visible = false
	slot_template.visible = false   # the template is copied, never shown
	$Center/Store/Top/CloseButton.pressed.connect(close)
	$Center/Store/Counter/VBox/Buttons/CancelButton.pressed.connect(close)
	Network.players_changed.connect(_refresh_players)
	# the shared store look: tiled roof (any width), scrolling body
	$Center/Store/Top/Roof.visible = false
	_top_parts = PixelStore.dress_top($Center/Store/Top, _awning(), "gold", $Center/Store/Top/Title, $Center/Store/Top/CloseButton)
	TouchScroll.setup(body_scroll)
	get_viewport().size_changed.connect(_apply_layout)
	visibility_changed.connect(func(): if visible: _apply_layout.call_deferred())


## Awning color of this store: "red" (host) or "blue" (join).
func _awning() -> String:
	return "red"


## Fits the window to the screen: about 92% of the safe area's height,
## at most 1100 wide, text about 4% of the viewport height, 64+ px buttons.
func _apply_layout() -> void:
	if not visible:
		return
	var vp := get_viewport()
	var m := PixelStore.metrics(vp)
	_m = m
	var safe := UiScale.safe_rect(vp)
	var width := floorf(minf(safe.size.x * 0.92, 1100.0))
	PixelStore.layout_top(_top_parts, width, m)
	store.custom_minimum_size = Vector2(width, 0)
	# players card (both windows)
	for l in [$Center/Store/Body/Scroll/VBox/PlayersCard/VBox/Header/Label, count_label]:
		l.add_theme_font_size_override("font_size", m["body"])
	for chip in [sili_chip, tubig_chip]:
		chip.add_theme_font_size_override("font_size", m["small"])
	slots.add_theme_constant_override("h_separation", int(m["gap"]))
	slots.add_theme_constant_override("v_separation", int(m["gap"] * 0.75))
	slot_template.custom_minimum_size.y = roundf(m["row"] * 0.92)
	slot_template.get_node("HBox/Name").add_theme_font_size_override("font_size", m["body"])
	slot_template.get_node("HBox/Name").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for tag in ["HBox/HostTag", "HBox/YouTag"]:
		slot_template.get_node(tag).add_theme_font_size_override("font_size", m["small"])
	slot_template.get_node("HBox/Dot").custom_minimum_size = Vector2.ONE * roundf(m["small"] * 0.6)
	# counter: status line and buttons (64+ px, well apart)
	status.add_theme_font_size_override("font_size", m["hint"])
	$Center/Store/Counter/VBox.add_theme_constant_override("separation", int(m["gap"]))
	$Center/Store/Counter/VBox/Buttons.add_theme_constant_override("separation", int(m["gap"] * 2.5))
	_size_png_button(cancel_button, m["button"])
	body_box.add_theme_constant_override("separation", int(m["gap"]))
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout_parts(m, width - 92.0)
	# the body fills the rest, so the window is ~92% of the safe height
	var counter_h := PixelStore.counter_height(m, status.text.count("
") + 1)
	body_scroll.custom_minimum_size.y = maxf(m["row"], floorf(safe.size.y * 0.92) - PixelStore.top_height(m) - counter_h - 24.0)
	PixelUI.fit_to_safe($Center, vp)
	_refresh_players()   # slot copies pick up the new sizes


## Each window sizes its own cards here (content_width = inside the shelves).
func _layout_parts(_m2: Dictionary, _content_width: float) -> void:
	pass


## A PNG button `height` tall, as wide as its picture's shape needs.
func _size_png_button(b: TextureButton, height: float) -> void:
	var tex := b.texture_normal
	var aspect := float(tex.get_width()) / float(tex.get_height()) if tex else 3.0
	b.custom_minimum_size = Vector2(roundf(height * aspect), height)


func close() -> void:
	Network.stop_listening()
	Network.leave()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# -------------------------------------------------------------- players
func _refresh_players() -> void:
	if not visible or not players_card.visible:
		return
	_clear(slots, slot_template)
	var ids := Network.sorted_ids()
	for i in Network.MAX_PLAYERS:
		slots.add_child(_slot(i, ids[i] if i < ids.size() else -1))
	var n := ids.size()
	var silis := Network.sili_count_for(max(n, Network.MIN_PLAYERS))
	count_label.text = "%d / %d" % [n, Network.MAX_PLAYERS]
	sili_chip.text = "%d SILI" % silis
	tubig_chip.text = "%d TUBIG" % max(n - silis, 0)
	if n == 2:
		sili_chip.text = "BOT SILI"   # 2 players: both Tubig, a bot Sili chases them
	_players_updated(n)
	var note := "A bot Sili will join this round."
	if n == 2 and not status.text.contains(note):
		status.text += ("
" if not status.text.is_empty() else "") + note
	elif n != 2 and status.text.contains(note):
		status.text = status.text.replace("
" + note, "").replace(note, "")


func _players_updated(_count: int) -> void:
	pass   # host_modal.gd uses this to turn START GAME on / off


func _slot(index: int, peer_id: int) -> Control:
	# a copy of Slots/SlotTemplate filled in for one player (or an open slot)
	var card := slot_template.duplicate()
	card.visible = true
	var dot: ColorRect = card.get_node("HBox/Dot")
	var name_label: Label = card.get_node("HBox/Name")
	card.get_node("HBox/HostTag").visible = peer_id == 1
	card.get_node("HBox/YouTag").visible = peer_id != -1 and peer_id == multiplayer.get_unique_id()
	if peer_id == -1:
		card.modulate.a = 0.45
		dot.color = Color(0.5, 0.5, 0.55)
		name_label.text = open_slot_text
		name_label.add_theme_color_override("font_color", hint_color)
		return card
	dot.color = slot_colors[index % slot_colors.size()]
	name_label.text = Network.player_name_of(peer_id)
	return card


# -------------------------------------------------------------- helpers
func _set_status(text: String, color: Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)


func _clear(box: Node, keep: Node) -> void:
	# remove the copies made last time, but keep the template
	for c in box.get_children():
		if c != keep:
			c.queue_free()
