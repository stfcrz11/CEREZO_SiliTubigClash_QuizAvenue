extends RefCounted
## The shared "sari-sari store" window: rooftop + brick band with a title
## plank, a striped awning, the shop body (shelves on both sides) and the
## wooden counter at the bottom for status text and buttons.
## Used by Host and Join (store_modal.gd dresses their scene), the
## Leaderboard, the Solo "resume" prompt and the end-of-round result.
##
##   const PixelStore := preload("res://scenes/pixel_store.gd")
##   var w := PixelStore.build_modal("blue", "gold", "TOP PLAYERS", true, false)
##   add_child(w["root"])  ... PixelStore.fit(w, get_viewport())
##
## Every size comes from the viewport height (metrics()), so windows look
## the same on a 960x640 PC window and on any phone. The art is drawn at 1x
## and scaled by a whole number (no blur).

const PixelUI := preload("res://scenes/pixel_ui.gd")
const UiScale := preload("res://scenes/ui_scale.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const PngButton := preload("res://scenes/png_button.gd")

const ROOF := preload("res://assets/ui/store_parts/roof_band.png")
const SIGN := preload("res://assets/ui/store_parts/sign_utang.png")
const CLOSE := preload("res://assets/ui/button_close.png")
const AWNINGS := {
	"red": preload("res://assets/ui/store_parts/awning_red.png"),
	"blue": preload("res://assets/ui/store_parts/awning_blue.png"),
}
const PLANKS := {
	"gold": preload("res://assets/ui/store_parts/plank_gold.png"),
	"red": preload("res://assets/ui/store_parts/plank_red.png"),
	"blue": preload("res://assets/ui/store_parts/plank_blue.png"),
}
const BODIES := {
	"red": preload("res://assets/ui/host_store/store_body.png"),
	"blue": preload("res://assets/ui/join_store/store_body.png"),
}
const COUNTERS := {
	"red": preload("res://assets/ui/host_store/store_counter.png"),
	"blue": preload("res://assets/ui/join_store/store_counter.png"),
}
const CHALKBOARD := preload("res://assets/ui/host_store/chalkboard.png")
const CARD := preload("res://assets/ui/card.png")

const BAND_ROWS := 32      # rooftop + brick band, in art pixels
const AWNING_ROWS := 27
const PLANK_TOP := 3       # the plank sits on the band from this art row...
const PLANK_ROWS := 28     # ...and is this many art pixels tall


## Sizes in UI units from the viewport height (never from a fixed resolution).
##   px      art pixel size (whole number, so the pixel art stays sharp)
##   body    body text (about 4% of the viewport height)
##   hint    hint / helper lines
##   small   chips and tags
##   title   pixel-font title (a multiple of 16)
##   big     big numbers (the host IP)
##   button  button height (64 at 720 px high, never less than 64)
##   row     list row height
##   gap     spacing between parts
static func metrics(vp: Viewport) -> Dictionary:
	var vh := vp.get_visible_rect().size.y
	return {
		"vh": vh,
		"px": maxi(2, int(vh / 320.0)),
		"body": maxi(18, int(round(vh * 0.042))),
		"hint": maxi(16, int(round(vh * 0.037))),
		"small": maxi(14, int(round(vh * 0.032))),
		"title": PixelUI.pixel_size(vh * 0.05),
		"big": maxi(28, int(round(vh * 0.07))),
		"button": maxf(64.0, round(vh * 64.0 / 720.0)),
		"row": maxf(64.0, round(vh * 0.1)),
		"gap": maxf(12.0, round(vh * 0.022)),
	}


## Expected height of the counter (status lines + one row of buttons).
## Worked out from the sizes, not measured: a wrapping Label reports a huge
## minimum height before it has a width.
static func counter_height(m: Dictionary, status_lines: int = 1, with_buttons: bool = true) -> float:
	var h: float = 32.0 + m["hint"] * 1.45 * status_lines
	if with_buttons:
		h += m["gap"] + m["button"]
	return h


## Height of the rooftop + awning, in UI units.
static func top_height(m: Dictionary) -> float:
	return (BAND_ROWS + AWNING_ROWS) * m["px"]


# ------------------------------------------------------------------ top
## Adds the tiled roof pieces to `top` (a plain Control). Returns the parts
## for layout_top(). The title Label and close button (if any) are kept
## above the art.
static func dress_top(top: Control, awning: String, plank: String, title: Label, close: Control = null) -> Dictionary:
	var band := _tiled(ROOF, "Band")
	var awn := _tiled(AWNINGS.get(awning, AWNINGS["red"]), "Awning")
	var sign := TextureRect.new()
	sign.name = "Sign"
	sign.texture = SIGN
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var board := NinePatchRect.new()
	board.name = "Plank"
	board.texture = PLANKS.get(plank, PLANKS["gold"])
	board.patch_margin_left = 3
	board.patch_margin_top = 3
	board.patch_margin_right = 3
	board.patch_margin_bottom = 3
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in [band, awn, sign, board].size():
		var part: Control = [band, awn, sign, board][i]
		top.add_child(part)
		top.move_child(part, i)
	style_title(title, plank)
	if close:
		top.move_child(close, -1)
	return {"top": top, "band": band, "awning": awn, "sign": sign, "plank": board, "title": title, "close": close}


## Title text on the plank: pixel font; dark red on gold, white on red/blue.
static func style_title(title: Label, plank: String) -> void:
	title.add_theme_font_override("font", PixelUI.PIXEL_FONT)
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if plank == "gold":
		title.add_theme_color_override("font_color", Color(0.62, 0.1, 0.08))
		title.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75))
		title.add_theme_constant_override("outline_size", 0)
	else:
		title.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
		title.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
		title.add_theme_constant_override("outline_size", 6)


## Places the roof pieces for a window `width` UI units wide.
static func layout_top(parts: Dictionary, width: float, m: Dictionary) -> void:
	var s: int = m["px"]
	var top: Control = parts["top"]
	top.custom_minimum_size = Vector2(width, top_height(m))
	var cols := ceilf(width / s)
	for key in ["band", "awning"]:
		var t: TextureRect = parts[key]
		t.scale = Vector2(s, s)
		t.position = Vector2(0, 0 if key == "band" else BAND_ROWS * s)
		t.size = Vector2(cols, BAND_ROWS if key == "band" else AWNING_ROWS)
	var title: Label = parts["title"]
	var font: int = m["title"]
	var close: Control = parts["close"]
	var close_w: float = m["button"] if close else 0.0
	# the plank fits the title, and never runs under the close button
	var max_plank := width - 2.0 * (close_w + 8.0 * s)
	font = PixelUI.pixel_size_fit(font, title.text, max_plank - 16.0 * s)
	title.add_theme_font_size_override("font_size", font)
	var want := title.text.length() * font * 0.75 + 20.0 * s
	var plank_w: float = clampf(want, minf(172.0 * s, max_plank), max_plank)
	plank_w = floorf(plank_w / s) * s
	var board: NinePatchRect = parts["plank"]
	board.scale = Vector2(s, s)
	board.size = Vector2(plank_w / s, PLANK_ROWS)
	board.position = Vector2(roundf((width - plank_w) / 2.0 / s) * s, PLANK_TOP * s)
	title.position = board.position
	title.size = Vector2(plank_w, PLANK_ROWS * s)
	var sign: TextureRect = parts["sign"]
	sign.scale = Vector2(s, s)
	sign.position = Vector2(4 * s, 11 * s)
	sign.visible = sign.position.x + SIGN.get_width() * s + 6 * s < board.position.x
	if close:
		close.size = Vector2(close_w, close_w)
		close.position = Vector2(width - close_w - 2 * s, 0)


static func _tiled(tex: Texture2D, node_name: String) -> TextureRect:
	var t := TextureRect.new()
	t.name = node_name
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


# ------------------------------------------------------------------ styles
## The shop body: brick shelves left and right, plaster in the middle.
static func body_style(awning: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = BODIES.get(awning, BODIES["red"])
	box.texture_margin_left = 36
	box.texture_margin_right = 36
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.content_margin_left = 46
	box.content_margin_right = 46
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


## The wooden counter under the body.
static func counter_style(awning: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = COUNTERS.get(awning, COUNTERS["red"])
	box.texture_margin_left = 8
	box.texture_margin_top = 14
	box.texture_margin_right = 8
	box.texture_margin_bottom = 6
	box.content_margin_left = 20
	box.content_margin_top = 18
	box.content_margin_right = 20
	box.content_margin_bottom = 14
	return box


## A green chalkboard with a wooden frame (host IP, result table).
static func chalkboard_style() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = CHALKBOARD
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 12)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 14
	box.content_margin_bottom = 16
	return box


## The dark card used inside the store (players list, games nearby).
static func card_style() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = CARD
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 14)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	return box


# ------------------------------------------------------------------ window
## A whole store window built in code. Returns its parts:
##   root (full-screen Control), dim, center, store, top, title, close (or
##   null), body, scroll (null when scroll_body is false), content (VBox
##   for your rows), counter, status (Label), buttons (HBox).
## The dim swallows every tap behind the window and does nothing itself.
static func build_modal(awning: String, plank: String, title_text: String, with_close: bool, scroll_body: bool = true) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := PixelUI.dim(0.72)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var store := VBoxContainer.new()
	store.name = "Store"
	store.add_theme_constant_override("separation", 0)
	center.add_child(store)
	var top := Control.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	store.add_child(top)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	top.add_child(title)
	var close: TextureButton = null
	if with_close:
		close = TextureButton.new()
		close.name = "CloseButton"
		close.texture_normal = CLOSE
		close.ignore_texture_size = true
		close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		close.tooltip_text = "Close (Esc)"
		close.focus_mode = Control.FOCUS_NONE
		close.set_script(PngButton)
		top.add_child(close)
	var top_parts := dress_top(top, awning, plank, title, close)
	var body := PanelContainer.new()
	body.name = "Body"
	body.add_theme_stylebox_override("panel", body_style(awning))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	store.add_child(body)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = null
	if scroll_body:
		scroll = ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(scroll)
		scroll.add_child(content)
		TouchScroll.setup(scroll)
	else:
		body.add_child(content)
	var counter := PanelContainer.new()
	counter.name = "Counter"
	counter.add_theme_stylebox_override("panel", counter_style(awning))
	store.add_child(counter)
	var footer := VBoxContainer.new()
	footer.name = "VBox"
	counter.add_child(footer)
	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	status.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	status.add_theme_constant_override("outline_size", 4)
	footer.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(buttons)
	return {"root": root, "dim": dim, "center": center, "store": store, "top": top, "top_parts": top_parts,
		"title": title, "close": close, "body": body, "scroll": scroll, "content": content,
		"counter": counter, "footer": footer, "status": status, "buttons": buttons}


## Sizes a build_modal() window: `height_frac` of the safe area's height
## (0 = as tall as its content), at most `max_width` wide, centered, never
## outside the safe area (notches, rounded corners).
static func fit(w: Dictionary, vp: Viewport, height_frac: float = 0.9, max_width: float = 1100.0) -> Dictionary:
	var m := metrics(vp)
	var safe := UiScale.safe_rect(vp)
	var width := floorf(minf(safe.size.x * 0.92, max_width))
	layout_top(w["top_parts"], width, m)
	var store: Control = w["store"]
	store.custom_minimum_size = Vector2(width, 0)
	var status: Label = w["status"]
	status.add_theme_font_size_override("font_size", m["hint"])
	status.visible = not status.text.is_empty()
	# a wrapping Label needs a width, or it reports one word per line
	# (a huge height that pushes the window off screen)
	status.custom_minimum_size.x = width - 80.0
	var footer: VBoxContainer = w["footer"]
	footer.add_theme_constant_override("separation", int(m["gap"]))
	var buttons: HBoxContainer = w["buttons"]
	buttons.add_theme_constant_override("separation", int(m["gap"] * 2.0))
	buttons.visible = buttons.get_child_count() > 0
	(w["content"] as VBoxContainer).add_theme_constant_override("separation", int(m["gap"]))
	var body: Control = w["body"]
	var inner: Control = w["scroll"] if w["scroll"] else w["content"]
	if height_frac > 0.0:
		var counter_h := counter_height(m, status.text.count("
") + 1, buttons.visible)
		var body_h := floorf(safe.size.y * height_frac) - top_height(m) - counter_h - 24.0
		inner.custom_minimum_size.y = maxf(body_h, m["row"])
	else:
		inner.custom_minimum_size.y = 0
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	PixelUI.fit_to_safe(w["center"], vp)
	return m


## Short drop-in with a small bounce (about 0.3 s). Moves the whole
## centered window by shifting both of its offsets together (moving
## `position` instead would freeze its current size into the offsets).
static func drop_in(center: Control, vp: Viewport) -> void:
	var top := center.offset_top
	var bottom := center.offset_bottom
	var drop := vp.get_visible_rect().size.y * 0.35
	var shift := func(d: float) -> void:
		center.offset_top = top - d
		center.offset_bottom = bottom - d
	shift.call(drop)
	center.create_tween().tween_method(shift, drop, 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A Label in the regular UI font at a given size and color.
static func label(text: String, size: int, color: Color = Color(0.95, 0.96, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
