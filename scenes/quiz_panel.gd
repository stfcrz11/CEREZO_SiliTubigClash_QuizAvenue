extends Control
## Question window, shown only to the player who is answering. A simple
## card, top to bottom:
##   QUIZ · SCROLL 3 · CORRECT 2 / 10                      12   <- heading + seconds left
##   Which festival is held in honor of the Santo Niño?          <- question
##   ==========-------                                            <- time bar
##   (A) Sinulog          (B) Pahiyas                             <- 2 x 2 answers
##   (C) Panagbenga       (D) Kadayawan                              (1 column if narrow)
##   [ ASK A TEAMMATE FOR HELP ]
## The heading names the quiz type: QUIZ, HULING HIRIT 1/2, BUHOS-TUBIG,
## HALO-HALO (cooler flavor), BUGTONG, KALAMANSI GATE.
## Answer by tapping / clicking, or keys A-D (1-4 also work). The host decides
## if the answer is right (maze_game.gd); show_result() then marks the right
## answer green with a check and a wrong pick red with an X.
## Built in code (sizes from scenes/ui_scale.gd) so it fits every screen.

signal choice_made(position: int)   # -1 = ran out of time
signal help_requested

const UiScale := preload("res://scenes/ui_scale.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const ICON_CHECK := preload("res://assets/ui/icon_check.png")
const ICON_X := preload("res://assets/ui/icon_x.png")
const LETTERS := ["A", "B", "C", "D"]

const PANEL_COLOR := Color(0.11, 0.12, 0.19)
const CARD_COLOR := Color(0.2, 0.22, 0.34)
const CARD_HOVER := Color(0.26, 0.29, 0.44)
const BADGE_COLOR := Color(0.33, 0.68, 1.0)
const HEADING_COLOR := Color(0.7, 0.74, 0.86)
const TIME_COLOR := Color(1.0, 0.75, 0.35)

@export var answer_time: float = 15.0

var entry: Dictionary
var order: Array = []          # order[i] = index into entry.choices shown at button i
var can_answer: bool = false
var waiting: bool = false
var time_left: float = 0.0
var _total_time: float = 15.0
var _help_used: bool = false   # this question already asked for help (or got told no one can)

var _center: CenterContainer
var _panel: PanelContainer
var header_label: Label        # the quiz type ("QUIZ", "HULING HIRIT 1/2", ...)
var subtitle_label: Label      # the rest of the heading line
var time_label: Label
var _time_bar: ProgressBar
var _question_scroll: ScrollContainer
var question_label: Label
var _grid: GridContainer
var choice_buttons: Array = []
var _badges: Array = []
var _marks: Array = []
var help_button: Button


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_layout)


func _build() -> void:
	add_child(PixelUI.dim(0.55))
	# the card is centred by a CenterContainer (Godot sizes it to its content)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	var frame := PixelUI.box_style(PANEL_COLOR, Color(0.36, 0.38, 0.5), 3)
	frame.set_corner_radius_all(14)
	frame.anti_aliasing = true
	frame.content_margin_left = 28
	frame.content_margin_right = 28
	frame.content_margin_top = 22
	frame.content_margin_bottom = 24
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", frame)
	_center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	# heading line: quiz type + details on the left, seconds on the right
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)
	header_label = Label.new()
	header_label.add_theme_color_override("font_color", TIME_COLOR)
	header_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(header_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_color_override("font_color", HEADING_COLOR)
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_label.clip_text = true
	top.add_child(subtitle_label)
	time_label = Label.new()
	time_label.add_theme_color_override("font_color", TIME_COLOR)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(time_label)

	# the question (scrolls if it is very long)
	_question_scroll = ScrollContainer.new()
	vbox.add_child(_question_scroll)
	question_label = Label.new()
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	question_label.add_theme_color_override("font_outline_color", Color(0.98, 0.98, 1.0))
	question_label.add_theme_constant_override("outline_size", 1)   # a little bolder
	_question_scroll.add_child(question_label)
	TouchScroll.setup(_question_scroll)

	# thin time bar
	_time_bar = ProgressBar.new()
	_time_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.22, 0.32)
	bg.set_corner_radius_all(4)
	_time_bar.add_theme_stylebox_override("background", bg)
	vbox.add_child(_time_bar)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(_grid)
	for i in 4:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick.bind(i))
		_grid.add_child(b)
		choice_buttons.append(b)
		var badge := Label.new()
		badge.text = LETTERS[i]
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color(0.06, 0.1, 0.2))
		var circle := StyleBoxFlat.new()
		circle.bg_color = BADGE_COLOR
		circle.set_corner_radius_all(64)
		badge.add_theme_stylebox_override("normal", circle)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		_badges.append(badge)
		var mark := TextureRect.new()
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible = false
		b.add_child(mark)
		_marks.append(mark)
		b.resized.connect(_place_badge.bind(i))
		_set_button_color(b, CARD_COLOR)

	help_button = PixelUI.button("ASK A TEAMMATE FOR HELP", "secondary", 44, 16)
	help_button.remove_theme_font_override("font")
	help_button.pressed.connect(_ask_help)
	vbox.add_child(help_button)


## Sizes for this screen (called when shown and on resize / rotation).
func _layout() -> void:
	if _panel == null:
		return
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	var safe := UiScale.safe_rect(vp)
	var width: float = UiScale.modal_size(vp, Vector2(0.88, 0.9), Vector2(720, 560)).x
	header_label.add_theme_font_size_override("font_size", UiScale.font(vp, 13))
	subtitle_label.add_theme_font_size_override("font_size", UiScale.font(vp, 13))
	time_label.add_theme_font_size_override("font_size", UiScale.font(vp, 30))
	question_label.add_theme_font_size_override("font_size", UiScale.font(vp, 22))
	_time_bar.custom_minimum_size.y = 8.0 * (1.4 if mobile else 1.0)
	_grid.columns = 1 if UiScale.is_narrow(vp) else 2
	var answer_h := maxf(UiScale.dp(vp, 56.0), 52.0) if mobile else 46.0
	var badge_size := answer_h * 0.5
	for i in 4:
		var b: Button = choice_buttons[i]
		b.custom_minimum_size.y = answer_h
		b.add_theme_font_size_override("font_size", UiScale.font(vp, 17))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = b.get_theme_stylebox(state)
			box.content_margin_left = badge_size + 26
			box.content_margin_right = badge_size + 14
		_badges[i].custom_minimum_size = Vector2.ONE * badge_size
		_badges[i].add_theme_font_size_override("font_size", int(badge_size * 0.55))
		_place_badge(i)
	help_button.custom_minimum_size.y = UiScale.touch_target(vp, 40.0)
	help_button.add_theme_font_size_override("font_size", UiScale.font(vp, 15))
	# question area: as tall as the text (measured with the font), but never
	# pushes the card off the screen; very long questions scroll
	var text_w := width - 56.0
	question_label.custom_minimum_size.x = text_w
	var qfont := question_label.get_theme_font("font")
	var qsize := question_label.get_theme_font_size("font_size")
	var text_h := qfont.get_multiline_string_size(question_label.text, HORIZONTAL_ALIGNMENT_LEFT, text_w, qsize).y + 6.0
	var answers_h := answer_h * (4.0 if _grid.columns == 1 else 2.0) + 12.0 * 3.0
	var others := 22.0 + 24.0 + UiScale.font(vp, 30) * 1.4 + _time_bar.custom_minimum_size.y + answers_h 		+ (help_button.custom_minimum_size.y + 14.0 if help_button.visible else 0.0) + 14.0 * 4.0
	_question_scroll.custom_minimum_size.y = clampf(text_h, 40.0, maxf(60.0, safe.size.y - others))
	_panel.custom_minimum_size = Vector2(width, 0)
	PixelUI.fit_to_safe(_center, vp)


func _place_badge(i: int) -> void:
	var b: Button = choice_buttons[i]
	var badge: Label = _badges[i]
	var s := badge.custom_minimum_size.x
	badge.size = Vector2(s, s)
	badge.position = Vector2(14, (b.size.y - s) / 2.0)
	var mark: TextureRect = _marks[i]
	mark.size = Vector2(s, s)
	mark.position = Vector2(b.size.x - s - 12, (b.size.y - s) / 2.0)


## seconds < 0 = the default answer_time (scrolls); quiz stations pass their own.
## header = the quiz type; subtitle = the rest of the heading line.
func show_question(q: Dictionary, shown_order: Array, header: String, answerer_is_me: bool,
		answerer_name: String, can_ask_help: bool = false, seconds: float = -1.0, subtitle: String = "") -> void:
	entry = q
	order = shown_order
	header_label.text = header
	subtitle_label.text = ("·  " + subtitle.to_upper()) if not subtitle.is_empty() else ""
	question_label.text = q["q"]
	_question_scroll.scroll_vertical = 0
	for i in choice_buttons.size():
		var b: Button = choice_buttons[i]
		b.text = q["choices"][order[i]]
		b.disabled = not answerer_is_me
		b.modulate = Color.WHITE
		_set_button_color(b, CARD_COLOR)
		_badges[i].visible = true
		_marks[i].visible = false
	can_answer = answerer_is_me
	help_button.visible = answerer_is_me and can_ask_help
	help_button.disabled = false
	help_button.text = _help_text()
	_help_used = false
	_total_time = answer_time if seconds < 0.0 else seconds
	time_left = _total_time
	_time_bar.max_value = _total_time
	waiting = true
	visible = answerer_is_me
	_layout()
	_update_timer()
	if answerer_is_me:
		Sound.start_loop("answering")   # plays while you answer


func _help_text() -> String:
	return "ASK A TEAMMATE FOR HELP" + ("" if GameState.is_mobile_ui() else " (H)")


func _set_button_color(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(10)
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		var old = b.get_theme_stylebox(state) if b.has_theme_stylebox_override(state) else null
		if old is StyleBoxFlat:
			box.content_margin_left = old.content_margin_left
			box.content_margin_right = old.content_margin_right
		match state:
			"hover":
				box.bg_color = CARD_HOVER if color == CARD_COLOR else color.lightened(0.1)
			"pressed":
				box.bg_color = color.darkened(0.15)
			_:
				box.bg_color = color
		b.add_theme_stylebox_override(state, box)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0.96, 0.96, 1.0))


func _process(delta: float) -> void:
	if not waiting or GameState.round_state == GameState.RoundState.PAUSED:
		return
	time_left -= delta
	_update_timer()
	if time_left <= 0.0 and can_answer:
		_pick(-1)


func _update_timer() -> void:
	var t := maxf(time_left, 0.0)
	time_label.text = str(ceili(t))
	_time_bar.value = t
	var urgent := t <= 3.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = PixelUI.RED if urgent else TIME_COLOR
	fill.set_corner_radius_all(4)
	_time_bar.add_theme_stylebox_override("fill", fill)
	time_label.add_theme_color_override("font_color", PixelUI.RED if urgent else TIME_COLOR)


func _unhandled_input(event: InputEvent) -> void:
	if not (waiting and can_answer and visible and event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.physical_keycode
	var pick := -1
	if k >= KEY_A and k <= KEY_D:
		pick = k - KEY_A
	elif k >= KEY_1 and k <= KEY_4:
		pick = k - KEY_1     # hidden alias
	if pick >= 0:
		_pick(pick)
		get_viewport().set_input_as_handled()
	elif k == KEY_H and help_button.visible and not help_button.disabled:
		_ask_help()
		get_viewport().set_input_as_handled()


func _ask_help() -> void:
	if not (waiting and can_answer) or help_button.disabled:
		return
	_help_used = true
	help_button.disabled = true
	help_button.text = "Asking your teammates..."
	help_requested.emit()


## Called when the host says nobody can help right now.
func help_unavailable() -> void:
	help_button.text = "No teammate can help right now"


## Only one Tubig can ask for help at a time: while someone else is asking,
## this button waits (it comes back when their request is over).
func set_help_locked(locked: bool, asker_name: String) -> void:
	if _help_used or not can_answer:
		return
	help_button.disabled = locked
	help_button.text = ("%s is already asking for help..." % asker_name) if locked else _help_text()


## Pressed at the same instant as someone else: wait for their request to end.
func help_rejected(asker_name: String) -> void:
	_help_used = false
	set_help_locked(true, asker_name)


func _pick(position: int) -> void:
	if not (waiting and can_answer):
		return
	can_answer = false
	help_button.disabled = true
	for b in choice_buttons:
		b.disabled = true
	# A/D also move the player: ignore movement keys until they are let go
	GameState.block_moves_until_released()
	choice_made.emit(position)


## Called with the host's verdict: the right answer turns green with a check,
## a wrong pick red with an X (icons, not colour alone). Input stays locked.
func show_result(chosen: int, correct: bool) -> void:
	waiting = false
	var correct_pos: int = order.find(entry["answer"])
	for i in choice_buttons.size():
		var b: Button = choice_buttons[i]
		b.disabled = true
		if i == correct_pos:
			_set_button_color(b, Color(0.2, 0.58, 0.32))
			_marks[i].texture = ICON_CHECK
			_marks[i].visible = true
		elif i == chosen:
			_set_button_color(b, Color(0.66, 0.22, 0.2))
			_marks[i].texture = ICON_X
			_marks[i].visible = true
		else:
			b.modulate = Color(1, 1, 1, 0.5)
	if chosen < 0:
		time_label.text = "0"


func close() -> void:
	waiting = false
	visible = false
	Sound.stop_loop()
