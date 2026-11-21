extends Control
## TOP PLAYERS window on the title screen, in the same sari-sari store look
## as Host / Join (built with scenes/pixel_store.gd). Shows the leaderboard
## saved on this device (data/leaderboard.gd). The rows scroll with a finger
## on phones (the header and legend stay in place).
## Close: the ✕, Esc / the Android Back button, or a tap outside the window.
##
##   var board := LeaderboardModal.new(); add_child(board); board.open()

## The saved file was damaged and had to be reset (the title screen shows it).
signal problem(message: String)

const PixelStore := preload("res://scenes/pixel_store.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const Leaderboard := preload("res://data/leaderboard.gd")

const MAX_ROWS := 20
const RANK_COLORS := [Color(1, 0.82, 0.3), Color(0.8, 0.84, 0.9), Color(0.85, 0.55, 0.3)]   # gold, silver, bronze
const HINT := Color(0.7, 0.74, 0.82)
const LEGEND := "Win %d  ·  Correct answer %d  ·  Tag %d  ·  Rescue %d"

var _w: Dictionary
var _legend: Label
var _header: HBoxContainer
var _rows_scroll: ScrollContainer
var _rows: VBoxContainer
var _empty: Label
var _card: PanelContainer


func _ready() -> void:
	name = "Leaderboard"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill the parent (a new Control has no size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_w = PixelStore.build_modal("red", "gold", "TOP PLAYERS", true, false)
	add_child(_w["root"])
	(_w["close"] as BaseButton).pressed.connect(close)
	# a tap outside the window closes it (like the other title windows)
	(_w["dim"] as Control).gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	var content: VBoxContainer = _w["content"]
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PixelStore.card_style())
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_card)
	var box := VBoxContainer.new()
	_card.add_child(box)
	_legend = PixelStore.label(LEGEND % [Leaderboard.WIN_POINTS, Leaderboard.CORRECT_POINTS,
		Leaderboard.TAG_POINTS, Leaderboard.RESCUE_POINTS], 16, HINT)
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # may wrap onto two lines
	box.add_child(_legend)
	var divider := ColorRect.new()
	divider.color = Color(1, 0.82, 0.3, 0.5)
	divider.custom_minimum_size = Vector2(0, 2)
	box.add_child(divider)
	_header = _row_box(["#", "PLAYER", "WINS", "PTS"], HINT)
	box.add_child(_header)
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_rows_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.add_child(_rows)
	TouchScroll.setup(_rows_scroll)
	_empty = PixelStore.label("No games yet.\nPlay a LAN round to get ranked!", 16, HINT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_empty)
	(_w["status"] as Label).text = "Saved on this device. Every LAN round counts."
	get_viewport().size_changed.connect(_layout)


func open() -> void:
	visible = true
	_fill()
	_layout()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## One row: rank | name | wins | points (the widths come from _layout()).
func _row_box(texts: Array, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	for i in texts.size():
		var l := PixelStore.label(texts[i], 16, color)
		l.name = ["Rank", "Name", "Wins", "Points"][i]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][i]
		if i == 1:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
	return row


func _fill() -> void:
	for old in _rows.get_children():
		if old != _empty:
			old.queue_free()
	var ranking := Leaderboard.rankings()
	if not Leaderboard.last_problem.is_empty():
		problem.emit(Leaderboard.last_problem)
		Leaderboard.last_problem = ""
	_empty.visible = ranking.is_empty()
	for i in mini(ranking.size(), MAX_ROWS):
		var r: Dictionary = ranking[i]
		var panel := PanelContainer.new()
		panel.name = "Row%d" % (i + 1)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS   # a finger drag on a row still scrolls
		var style := PixelUI.box_style(Color(0.14, 0.17, 0.26, 0.95), Color(0.08, 0.09, 0.13), 2)
		panel.add_theme_stylebox_override("panel", style)
		var row := _row_box([str(i + 1), r["name"], str(r["wins"]), str(r["points"])], Color(0.95, 0.96, 1.0))
		var rank_color: Color = RANK_COLORS[i] if i < RANK_COLORS.size() else HINT
		row.get_node("Rank").add_theme_color_override("font_color", rank_color)
		row.get_node("Points").add_theme_color_override("font_color", Color(0.5, 0.95, 0.55))
		if (r["name"] as String).to_lower() == GameState.player_name.to_lower():
			row.get_node("Name").add_theme_color_override("font_color", Color(1, 0.88, 0.35))   # you
		panel.tooltip_text = "%s — %d games, %d wins, %d points" % [r["name"], r["games"], r["wins"], r["points"]]
		panel.add_child(row)
		_rows.add_child(panel)
	if visible:
		_layout()


func _layout() -> void:
	if not visible:
		return
	var vp := get_viewport()
	var m := PixelStore.fit(_w, vp, 0.92, 900.0)
	_legend.add_theme_font_size_override("font_size", m["hint"])
	_empty.add_theme_font_size_override("font_size", m["body"])
	_rows.add_theme_constant_override("separation", int(m["gap"] * 0.5))
	var rank_w: float = m["body"] * 2.2
	var num_w: float = m["body"] * 3.6
	for row in [_header] + _rows.get_children().filter(func(c): return c is PanelContainer).map(func(c): return c.get_child(0)):
		var hb: HBoxContainer = row
		hb.add_theme_constant_override("separation", int(m["gap"]))
		var size: int = m["small"] if hb == _header else m["body"]
		for l in hb.get_children():
			l.add_theme_font_size_override("font_size", size)
		hb.get_node("Rank").custom_minimum_size.x = rank_w
		hb.get_node("Wins").custom_minimum_size.x = num_w
		hb.get_node("Points").custom_minimum_size.x = num_w
		if hb != _header:
			(hb.get_parent() as Control).custom_minimum_size.y = maxf(56.0, roundf(m["row"] * 0.9))
