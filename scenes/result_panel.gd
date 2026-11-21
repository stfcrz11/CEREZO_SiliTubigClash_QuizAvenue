extends Control
## End-of-round result window ("TUBIG WINS!" / "SILI WINS!") in the same
## sari-sari store look as Host / Join (scenes/pixel_store.gd):
##   Tubig win  -> blue/white awning, blue title plank, water drop
##   Sili win   -> red/white awning, red title plank, ice block
##   no winner  -> red awning, gold plank (e.g. the host left)
## The stats sit on a chalkboard; the panel drops in with a small bounce.
##
## maze_game.gd decides everything (win / lose, texts, button actions) and
## writes into result_label, stats_label and the two buttons exactly as
## before, then calls present(). present() only arranges what is written:
## the title becomes the plank + the reason line, the "Correct answers /
## Scrolls opened / Time left" lines become the chalkboard table, and the
## other lines stay in stats_label (notes under the table).

const PixelStore := preload("res://scenes/pixel_store.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const ICE := preload("res://assets/props/ice_block.png")
const DROP := preload("res://assets/ui/store_parts/icon_drop.png")

## Lines of the stats text shown as table rows (everything else is a note).
const TABLE_KEYS := ["Correct answers", "Scrolls opened", "Time left"]
const CHALK := Color(0.93, 0.95, 0.9)
const CHALK_GOLD := Color(1.0, 0.86, 0.4)

## Written by maze_game.gd (same names as the old EndPanel labels).
var result_label := Label.new()       # the title, e.g. "SILI WINS! STEF STAYED FROZEN"
var stats_label := Label.new()        # the stats + notes text
var play_again_button: Button
var menu_button: Button

var _kind := ""
var _w: Dictionary = {}
var _verdict: Label
var _icon: TextureRect
var _icon_tile: PanelContainer        # dark tile behind the icon (the ice is see-through)
var _reason: Label
var _table: GridContainer
var _board: PanelContainer
var _rows: Array = []                 # [[key, value], ...]


func _ready() -> void:
	name = "EndPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill the parent (a new Control has no size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	play_again_button = PixelUI.button("Play Again", "primary", 64, 32)
	play_again_button.name = "PlayAgainButton"
	menu_button = PixelUI.button("Main Menu", "danger", 64, 32)
	menu_button.name = "MenuButton"
	result_label.name = "ResultLabel"
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.18))
	_verdict = PixelUI.pixel_label("", 32, PixelUI.GOLD_TEXT)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_tile = PanelContainer.new()
	_icon_tile.add_theme_stylebox_override("panel", PixelUI.box_style(PixelUI.NAVY, PixelUI.OUTLINE, 4))
	_icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_tile.add_child(_icon)
	_reason = PixelUI.pixel_label("", 32, CHALK_GOLD)
	_reason.remove_theme_color_override("font_outline_color")
	_reason.add_theme_constant_override("outline_size", 0)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_table = GridContainer.new()
	_table.columns = 2
	_board = PanelContainer.new()
	_board.add_theme_stylebox_override("panel", PixelStore.chalkboard_style())
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board_box := VBoxContainer.new()
	board_box.add_child(_reason)
	board_box.add_child(_table)
	_board.add_child(board_box)
	_build("neutral")
	get_viewport().size_changed.connect(apply_layout)


## Show the result. kind: "tubig" (Tubig team won), "sili" or "neutral".
func present(kind: String) -> void:
	if kind != _kind:
		_build(kind)
	var parts := _split_title(result_label.text, kind)
	(_w["title"] as Label).text = parts[0]
	_reason.text = parts[1]
	_reason.visible = not parts[1].is_empty()
	_read_stats()
	_icon.texture = ICE if kind == "sili" else (DROP if kind == "tubig" else null)
	_icon_tile.visible = _icon.texture != null
	_verdict.visible = not _verdict.text.is_empty()
	# button colors follow the HUD buttons: red = leave, grey = retry, gold = go on
	play_again_button.text = play_again_button.text.to_upper()
	menu_button.text = menu_button.text.to_upper()
	var retry := play_again_button.text.begins_with("RETRY")
	PixelUI.ButtonStyle.style_primary(play_again_button,
		Color(0.42, 0.44, 0.5) if retry else PixelUI.GOLD,
		Color(1, 1, 1) if retry else Color(0.16, 0.11, 0.09))
	PixelUI.ButtonStyle.style_primary(menu_button, Color(0.84, 0.23, 0.18), Color(1, 0.98, 0.95))
	visible = true
	apply_layout()
	PixelStore.drop_in(_w["center"], get_viewport())


## (Re)builds the store window in the colors of `kind`; the labels and
## buttons are moved over, so maze_game.gd keeps the same objects.
func _build(kind: String) -> void:
	_kind = kind
	for n in [result_label, stats_label, play_again_button, menu_button, _verdict, _icon_tile, _board]:
		if n.get_parent():
			n.get_parent().remove_child(n)
	if not _w.is_empty():
		(_w["root"] as Node).queue_free()
	var awning := "blue" if kind == "tubig" else "red"
	var plank := "blue" if kind == "tubig" else ("red" if kind == "sili" else "gold")
	_w = PixelStore.build_modal(awning, plank, "", false, true)
	add_child(_w["root"])
	var content: VBoxContainer = _w["content"]
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 16)
	head.add_child(_icon_tile)
	head.add_child(_verdict)
	content.add_child(head)
	content.add_child(_board)
	content.add_child(stats_label)
	result_label.visible = false
	content.add_child(result_label)     # kept as the title's text holder
	var buttons: HBoxContainer = _w["buttons"]
	buttons.add_child(play_again_button)
	buttons.add_child(menu_button)


## "SILI WINS! STEF STAYED FROZEN" -> ["SILI WINS!", "STEF STAYED FROZEN"];
## "TIME'S UP — SILI WINS!" -> ["SILI WINS!", "TIME'S UP"].
func _split_title(title: String, kind: String) -> Array:
	var t := title.replace("—", "-").strip_edges()
	var head := ""
	for win in ["TUBIG TEAM WINS!", "TUBIG WINS!", "SILI WINS!"]:
		if t.contains(win):
			head = "TUBIG WINS!" if win.begins_with("TUBIG") else "SILI WINS!"
			t = t.replace(win, "")
			break
	if head.is_empty():
		var cut := t.find(" - ")
		head = t.substr(0, cut) if cut > 0 else t
		t = t.substr(cut + 3) if cut > 0 else ""
	var reason := t.strip_edges().trim_prefix("-").trim_suffix("-").strip_edges()
	if reason.is_empty() and kind == "tubig":
		reason = "ALL QUESTIONS ANSWERED"
	return [head, reason]


## Splits stats_label's text into the verdict, the table rows and the notes.
func _read_stats() -> void:
	_rows.clear()
	var notes: Array[String] = []
	_verdict.text = ""
	for line in stats_label.text.split("\n"):
		var key := line.get_slice(": ", 0)
		if line.contains(": ") and key in TABLE_KEYS:
			_rows.append([key, line.substr(key.length() + 2)])
		elif line in ["You win!", "You lose!"]:
			_verdict.text = line.to_upper()
			_verdict.add_theme_color_override("font_color", PixelUI.GREEN if line == "You win!" else PixelUI.RED)
		else:
			notes.append(line)
	stats_label.text = "\n".join(notes).strip_edges()
	stats_label.visible = not stats_label.text.is_empty()
	for c in _table.get_children():
		c.queue_free()
	for r in _rows:
		var k := PixelUI.pixel_label(r[0], 32, CHALK)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := PixelUI.pixel_label(r[1], 32, CHALK_GOLD)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for l in [k, v]:
			l.remove_theme_color_override("font_outline_color")
			l.add_theme_constant_override("outline_size", 0)
			l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		_table.add_child(k)
		_table.add_child(v)
	_board.visible = not _rows.is_empty() or _reason.visible


## Sizes from the viewport height; pixel text only at sharp sizes (16/32/48).
func apply_layout() -> void:
	if not visible:
		return
	var vp := get_viewport()
	var m := PixelStore.fit(_w, vp, 0.0, 820.0)
	var width: float = (_w["store"] as Control).custom_minimum_size.x
	var inner := width - 92.0
	var s: int = m["px"]
	_icon.custom_minimum_size = Vector2(ICE.get_width(), ICE.get_height()) * s if _icon.texture == ICE \
		else Vector2(DROP.get_width(), DROP.get_height()) * s * 2
	_verdict.add_theme_font_size_override("font_size", PixelUI.pixel_size_fit(m["title"], _verdict.text, inner - 120.0))
	var table_font := 32
	for r in _rows:
		table_font = mini(table_font, PixelUI.pixel_size_fit(32, r[0] + "   " + r[1], inner - 60.0))
	for l in _table.get_children():
		(l as Label).add_theme_font_size_override("font_size", table_font)
	_table.add_theme_constant_override("h_separation", int(m["gap"] * 2))
	_table.add_theme_constant_override("v_separation", int(m["gap"] * 0.5))
	_reason.add_theme_font_size_override("font_size", PixelUI.pixel_size_fit(32, _reason.text, inner - 60.0))
	_reason.custom_minimum_size.x = inner - 60.0
	stats_label.add_theme_font_size_override("font_size", m["hint"])
	stats_label.custom_minimum_size.x = inner
	var bw := floorf((inner - m["gap"] * 2.0) / 2.0)
	for b in [play_again_button, menu_button]:
		b.custom_minimum_size = Vector2(bw, m["button"])
		b.add_theme_font_size_override("font_size", PixelUI.pixel_size_fit(32, b.text, bw - 16.0))
	# never taller than the safe area: the body scrolls if the notes are long
	var scroll: ScrollContainer = _w["scroll"]
	var content: Control = _w["content"]
	var safe_h := PixelStore.UiScale.safe_rect(vp).size.y
	var max_body := floorf(safe_h * 0.92) - PixelStore.top_height(m) - PixelStore.counter_height(m, 0) - 24.0
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, max_body)
