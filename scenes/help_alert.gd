extends Control
## Bottom-right alert a Tubig sees when a teammate asks for help with a
## question: "<name> needs help with the question! Do you want to help?"
## YES / NO (or keys Y / N). The game keeps running while it is shown.
## maze_game.gd opens and closes it; only the first YES from any teammate
## gets the question (the host decides).
## To customize: open scenes/help_alert.tscn and click "HelpAlert" for the
## texts in the Inspector, or click a node to change its look.

signal answered(yes: bool)

@export var message_text: String = "%s needs help with the question!\nDo you want to help?"   # %s = name

@onready var message: Label = $Panel/Margin/VBox/Message
@onready var yes_button: Button = $Panel/Margin/VBox/Buttons/YesButton
@onready var no_button: Button = $Panel/Margin/VBox/Buttons/NoButton

const ButtonStyle := preload("res://scenes/ui_button_style.gd")
const UiScale := preload("res://scenes/ui_scale.gd")


func _ready() -> void:
	visible = false
	ButtonStyle.style_primary(yes_button, Color(0.25, 0.72, 0.4), Color(1, 1, 1))
	ButtonStyle.style_secondary(no_button, Color(0.4, 0.4, 0.48))
	yes_button.pressed.connect(_answer.bind(true))
	no_button.pressed.connect(_answer.bind(false))
	# key hints only on desktop
	yes_button.text = "YES" if GameState.is_mobile_ui() else "YES (Y)"
	no_button.text = "NO" if GameState.is_mobile_ui() else "NO (N)"


## Bigger text and buttons on phones (maze_game calls this on resize too).
func apply_ui_scale() -> void:
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	$Panel/Margin/VBox/Title.add_theme_font_size_override("font_size", UiScale.font(vp, 14))
	message.add_theme_font_size_override("font_size", UiScale.font(vp, 16))
	message.custom_minimum_size.x = 288.0 * (1.35 if mobile else 1.0)
	for b in [yes_button, no_button]:
		b.custom_minimum_size = Vector2(130.0 * (1.3 if mobile else 1.0), UiScale.touch_target(vp, 36.0))
		b.add_theme_font_size_override("font_size", UiScale.font(vp, 16))
	$Panel.offset_left = -340.0 * (1.4 if mobile else 1.0)


func open(asker_name: String) -> void:
	message.text = message_text % asker_name
	# with touch controls, sit above the joystick's resting spot (bottom right)
	var lift := 170.0 * UiScale.touch_target(get_viewport(), 64.0) / 64.0 if GameState.touch_controls_on() else 0.0
	var h := 134.0 * (1.5 if GameState.is_mobile_ui() else 1.0)
	$Panel.offset_bottom = -56.0 - lift
	$Panel.offset_top = $Panel.offset_bottom - h
	visible = true


func close() -> void:
	visible = false


func _answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	answered.emit(yes)


func _unhandled_input(event: InputEvent) -> void:
	if not (visible and event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_Y:
		_answer(true)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_N:
		_answer(false)
		get_viewport().set_input_as_handled()
