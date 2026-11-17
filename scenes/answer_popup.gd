extends Control
## The big "TAMA!" / "MALI!" / "TIME'S UP!" result popup. Only the player who
## answered sees it (everyone else gets a one-line message from
## maze_game.gd). Pixel style, built in code so it fits every screen:
## a huge colour-coded headline with an icon, who answered, the correct
## answer on a yellow plaque, the fun fact, the progress line and points.
## Pops in with a bounce; TAMA bursts water drops and confetti, MALI shakes
## with a red flash. A tap or key press closes it early, otherwise it closes
## by itself after 3.5-4.5 s (longer for long text). `dismissed` fires once
## when it closes (maze_game tells the host, which then resumes play).
## Words and colours can be changed in the Inspector (click AnswerPopup).

signal dismissed

const UiScale := preload("res://scenes/ui_scale.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const ICON_CHECK := preload("res://assets/ui/icon_check.png")
const ICON_X := preload("res://assets/ui/icon_x.png")
const ICON_TIME := preload("res://assets/ui/icon_hourglass.png")

@export_group("Texts")
@export var correct_word: String = "TAMA!"
@export var wrong_word: String = "MALI!"
@export var timeout_word: String = "TIME'S UP!"
@export var answered_text: String = "%s answered"            # %s = player name
@export var timeout_text: String = "%s ran out of time"
@export var answer_text: String = "Answer: %s"
@export var score_text: String = "Questions %d / %d"

@export_group("Colors")
@export var correct_color: Color = Color(0.35, 0.9, 0.45)
@export var wrong_color: Color = Color(1.0, 0.4, 0.35)
@export var timeout_color: Color = Color(1.0, 0.68, 0.25)

var _center: CenterContainer
var _panel: PanelContainer
var _icon: TextureRect
var big_word: Label
var who_label: Label
var _answer_box: PanelContainer
var answer_label: Label
var fact_label: Label
var score_label: Label
var points_label: Label
var _flash: ColorRect
var _burst: CPUParticles2D
var _timer: SceneTreeTimer
var _open_time: float = 0.0     # seconds the popup has been showing
var _open: bool = false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # a tap anywhere closes it, nothing behind reacts
	gui_input.connect(_on_gui_input)
	_build()
	get_viewport().size_changed.connect(_layout)


func _build() -> void:
	var dim := PixelUI.dim(0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelUI.panel_style(26))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.resized.connect(func(): _panel.pivot_offset = _panel.size / 2.0)
	_center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(head)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)
	big_word = PixelUI.pixel_label("TAMA!", 64, correct_color)
	head.add_child(big_word)
	who_label = _text_label(Color(0.78, 0.82, 0.92))
	vbox.add_child(who_label)
	_answer_box = PanelContainer.new()
	_answer_box.add_theme_stylebox_override("panel", PixelUI.box_style(PixelUI.GOLD, PixelUI.OUTLINE, 4))
	_answer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_answer_box)
	answer_label = _text_label(Color(0.16, 0.11, 0.09))
	_answer_box.add_child(answer_label)
	fact_label = _text_label(Color(0.95, 0.95, 1.0))
	vbox.add_child(fact_label)
	score_label = _text_label(Color(1.0, 0.85, 0.4))
	vbox.add_child(score_label)
	points_label = _text_label(PixelUI.GREEN)
	vbox.add_child(points_label)
	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.amount = 60
	_burst.lifetime = 1.2
	_burst.explosiveness = 0.95
	_burst.direction = Vector2(0, -1)
	_burst.spread = 75.0
	_burst.gravity = Vector2(0, 600)
	_burst.initial_velocity_min = 260.0
	_burst.initial_velocity_max = 520.0
	_burst.scale_amount_min = 4.0
	_burst.scale_amount_max = 8.0
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	colors.colors = PackedColorArray([Color(0.4, 0.75, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 0.9, 1.0), Color(1.0, 0.45, 0.4)])
	_burst.color_initial_ramp = colors
	add_child(_burst)


func _text_label(color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## result_line: replaces the progress line (quiz stations, rescues).
## points: shown as "+N point(s)" when more than 0.
func open(correct: bool, timed_out: bool, picker_name: String, right_answer: String,
		fact: String, score: int, goal: int, result_line: String = "", points: int = 0) -> void:
	var color := correct_color if correct else (timeout_color if timed_out else wrong_color)
	big_word.text = correct_word if correct else (timeout_word if timed_out else wrong_word)
	big_word.add_theme_color_override("font_color", color)
	_icon.texture = ICON_CHECK if correct else (ICON_TIME if timed_out else ICON_X)
	who_label.text = (timeout_text if timed_out else answered_text) % picker_name
	answer_label.text = answer_text % right_answer
	fact_label.text = fact
	fact_label.visible = not fact.is_empty()
	score_label.text = result_line if not result_line.is_empty() else score_text % [score, goal]
	points_label.text = ("+%d point%s" % [points, "" if points == 1 else "s"]) if points > 0 else ""
	points_label.visible = points > 0
	var frame := _panel.get_theme_stylebox("panel") as StyleBoxTexture
	frame.modulate_color = color.lerp(Color.WHITE, 0.55)
	visible = true
	_open = true
	_open_time = 0.0
	_layout()
	_animate(correct, timed_out, color)
	# closes by itself; longer text stays a little longer
	var seconds := clampf(3.5 + (fact.length() + right_answer.length()) / 140.0, 3.5, 4.5)
	var timer := get_tree().create_timer(seconds)
	_timer = timer
	timer.timeout.connect(func():
		if _timer == timer:
			close())


func _layout() -> void:
	if _panel == null or not visible:
		return
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	var safe := UiScale.safe_rect(vp)
	var width := safe.size.x * (0.8 if mobile else 0.62)
	width = clampf(width, minf(420.0, safe.size.x), safe.size.x * 0.92)
	# huge headline: about 1/4 of the screen height on phones
	# the headline + its icon must fit inside the panel
	var head_target := safe.size.y * (0.16 if mobile else 0.12)
	var head := PixelUI.pixel_size_fit(head_target, big_word.text, (width - 60.0) / (1.0 + 1.3 / maxf(1.0, big_word.text.length() * 0.75)))
	big_word.add_theme_font_size_override("font_size", head)
	_icon.custom_minimum_size = Vector2.ONE * head * 1.1
	who_label.add_theme_font_size_override("font_size", UiScale.font(vp, 16))
	answer_label.add_theme_font_size_override("font_size", UiScale.font(vp, 22))
	score_label.add_theme_font_size_override("font_size", UiScale.font(vp, 17))
	points_label.add_theme_font_size_override("font_size", UiScale.font(vp, 17))
	var fact_size := UiScale.font(vp, 18)
	if fact_label.text.length() > 140:
		fact_size = UiScale.font(vp, 16)
	fact_label.add_theme_font_size_override("font_size", fact_size)
	# wrapped text needs its width up front so its height is right
	var text_w := width - 60.0
	for l in [who_label, answer_label, fact_label, score_label, points_label]:
		l.custom_minimum_size.x = text_w
	answer_label.custom_minimum_size.x = text_w - 28.0
	_panel.custom_minimum_size = Vector2(width, 0)
	PixelUI.fit_to_safe(_center, vp)
	_burst.position = safe.position + Vector2(safe.size.x / 2.0, safe.size.y * 0.3)


func _animate(correct: bool, timed_out: bool, color: Color) -> void:
	_panel.scale = Vector2(0.55, 0.55)
	var pop := create_tween()
	pop.tween_property(_panel, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_panel, "scale", Vector2.ONE, 0.1)
	var flash_color := Color(1, 1, 1, 0.45) if correct else Color(color.r, color.g * 0.4, color.b * 0.4, 0.4)
	_flash.color = flash_color
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
	if correct:
		_burst.restart()
		_burst.emitting = true
	else:
		# a short shake (MALI), gentler for TIME'S UP
		await get_tree().process_frame     # let the container place the panel first
		var home := _panel.position
		var amount := 14.0 if not timed_out else 7.0
		var shake := create_tween()
		for i in 6:
			shake.tween_property(_panel, "position", home + Vector2(amount * (1 if i % 2 == 0 else -1), 0), 0.04)
		shake.tween_property(_panel, "position", home, 0.04)


func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_try_dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and not event.echo:
		_try_dismiss()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _open:
		_open_time += delta


func _try_dismiss() -> void:
	# ignore taps in the first moment (the finger that picked the answer)
	if _open_time > 0.4:
		close()


func close() -> void:
	visible = false
	_timer = null
	if _open:
		_open = false
		dismissed.emit()
