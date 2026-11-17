extends Control
## Reusable "Are you sure?" window in the game's pixel style. A dimmed
## layer blocks every tap behind it (joystick and RUN included); tapping the
## dim does nothing. Esc / the Android Back button = the safe choice.
##
##   modal.ask("LEAVE GAME?", "Your progress will be lost.", "STAY", "LEAVE")
##   var ok: bool = await modal.answered        # true = the danger button
##   modal.tell("WAIT", "You can leave when the round is over.")   # one OK button
##
## Built in code (scenes/pixel_ui.gd + scenes/ui_scale.gd); fits every screen.

signal answered(confirmed: bool)

const UiScale := preload("res://scenes/ui_scale.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")

var _center: CenterContainer
var _panel: PanelContainer
var _tab: PanelContainer
var _message: Label
var _buttons: HBoxContainer
var _safe_button: Button
var _danger_button: Button
var _open: bool = false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(PixelUI.dim(0.65))
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelUI.panel_style(28))
	_panel.resized.connect(func(): _panel.pivot_offset = _panel.size / 2.0)
	_center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	_panel.add_child(vbox)
	_tab = PixelUI.plaque("LEAVE GAME?", 32)
	_tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_tab)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	vbox.add_child(_message)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 28)
	vbox.add_child(_buttons)
	_safe_button = PixelUI.button("STAY", "primary", 56, 16)
	_danger_button = PixelUI.button("LEAVE", "danger", 56, 16)
	_buttons.add_child(_safe_button)
	_buttons.add_child(_danger_button)
	_safe_button.pressed.connect(_finish.bind(false))
	_danger_button.pressed.connect(_finish.bind(true))
	get_viewport().size_changed.connect(_layout)


## Two buttons: a safe one (gold, the default) and a danger one (red).
func ask(title: String, message: String, safe_text: String, danger_text: String) -> void:
	_show(title, message, safe_text, danger_text)


## One OK button (just information).
func tell(title: String, message: String, ok_text: String = "OK") -> void:
	_show(title, message, ok_text, "")


func is_open() -> bool:
	return _open


func _show(title: String, message: String, safe_text: String, danger_text: String) -> void:
	_tab.get_node("Text").text = title
	_message.text = message
	_safe_button.text = safe_text
	_danger_button.text = danger_text
	_danger_button.visible = not danger_text.is_empty()
	visible = true
	_open = true
	_layout()
	_panel.scale = Vector2(0.8, 0.8)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _layout() -> void:
	if not visible:
		return
	var vp := get_viewport()
	var safe := UiScale.safe_rect(vp)
	var mobile := GameState.is_mobile_ui()
	var width := minf(safe.size.x * (0.7 if mobile else 0.5), 640.0 if not mobile else safe.size.x)
	width = maxf(width, minf(420.0, safe.size.x))
	var button_h := maxf(UiScale.dp(vp, 56.0), 52.0) if mobile else 50.0
	var font := PixelUI.pixel_size(UiScale.font(vp, 18))
	for b in [_safe_button, _danger_button]:
		b.custom_minimum_size = Vector2(maxf(170.0, width * 0.36), button_h)
		b.add_theme_font_size_override("font_size", font)
	_buttons.add_theme_constant_override("separation", int(button_h * 0.5))
	_message.add_theme_font_size_override("font_size", UiScale.font(vp, 19))
	var title: Label = _tab.get_node("Text")
	title.add_theme_font_size_override("font_size", PixelUI.pixel_size_fit(UiScale.font(vp, 24), title.text, width - 80.0))
	_message.custom_minimum_size.x = width - 60.0
	_panel.custom_minimum_size = Vector2(width, 0)
	PixelUI.fit_to_safe(_center, vp)


func _finish(confirmed: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	answered.emit(confirmed)


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		_finish(false)          # Esc / Back = the safe choice
		get_viewport().set_input_as_handled()
