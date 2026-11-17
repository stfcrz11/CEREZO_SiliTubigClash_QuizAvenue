extends Control
## SETTINGS window, opened by the gear button (title screen and in game).
## Music / Sound effects: on-off switch + volume slider (saved on this
## device by the Sound autoload). CONTROLS: the list of keys.
## Close with the X, Esc, or a click outside. It does NOT pause a LAN game.
## To customize: open scenes/settings_panel.tscn and click any node.
## Phones only: the touch-controls and vibration switches, touch wording in
## the controls list, bigger text. Desktop: keyboard wording, no joystick
## switch. The window scrolls if it doesn't fit.

const UiScale := preload("res://scenes/ui_scale.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const KEY := "[bgcolor=#33405e][color=#ffffff][b] %s [/b][/color][/bgcolor]"

@onready var music_on: CheckButton = $Center/Panel/Margin/VBox/MusicRow/On
@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/MusicRow/Slider
@onready var music_value: Label = $Center/Panel/Margin/VBox/MusicRow/Value
@onready var sfx_on: CheckButton = $Center/Panel/Margin/VBox/SfxRow/On
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value: Label = $Center/Panel/Margin/VBox/SfxRow/Value
@onready var touch_on: CheckButton = $Center/Panel/Margin/VBox/TouchRow/On
@onready var vibration_on: CheckButton = $Center/Panel/Margin/VBox/VibrationRow/On
@onready var fps_on: CheckButton = $Center/Panel/Margin/VBox/FpsRow/On
@onready var reset_button: Button = $Center/Panel/Margin/VBox/ResetRow/ResetButton
var _reset_armed := false   # Reset needs two taps, so it can't happen by accident


func _ready() -> void:
	visible = false
	$Center/Panel/Margin/VBox/Header/CloseButton.pressed.connect(close)
	$Dim.gui_input.connect(_on_dim_input)
	music_on.toggled.connect(func(_on): _music_changed())
	music_slider.value_changed.connect(func(_v): _music_changed())
	sfx_on.toggled.connect(func(_on): _sfx_changed())
	sfx_slider.value_changed.connect(func(_v): _sfx_changed())
	touch_on.toggled.connect(func(on): GameState.set_touch_controls(on))
	vibration_on.toggled.connect(func(on): GameState.set_vibration(on))
	fps_on.toggled.connect(func(on): GameState.set_show_fps(on))
	reset_button.pressed.connect(_on_reset)
	preload("res://scenes/ui_button_style.gd").style_secondary(reset_button, Color(0.72, 0.22, 0.18))
	_make_scrollable()


## Puts the settings list in a ScrollContainer (big phone text may not fit).
func _make_scrollable() -> void:
	var vbox: Control = $Center/Panel/Margin/VBox
	var margin := vbox.get_parent()
	margin.remove_child(vbox)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	margin.add_child(scroll)
	scroll.add_child(vbox)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TouchScroll.setup(scroll)


## Platform-specific rows and wording, and text sizes for this screen.
func _apply_platform() -> void:
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	var vbox: Control = music_on.get_parent().get_parent()
	vbox.get_node("TouchRow").visible = mobile
	vbox.get_node("VibrationRow").visible = mobile
	var controls: RichTextLabel = vbox.get_node("Controls")
	if mobile:
		controls.text = "Drag the [b]right half[/b] to move · hold [b]RUN[/b] to sprint · tap [b]USE[/b] at a station\n" + \
			"Tap an answer · tap [b]YES / NO[/b] for help · [b]door[/b] = leave, [b]pause[/b], [b]Back[/b] = pause / close\n" + \
			"[color=#9aa4b8]Full list: HOW TO PLAY on the title screen.[/color]"
	else:
		controls.text = (KEY % "W A S D") + " move   " + (KEY % "Shift") + " sprint   " + (KEY % "E") + " use a station\n" + \
			(KEY % "A") + (KEY % "B") + (KEY % "C") + (KEY % "D") + " answer   " + (KEY % "H") + " help   " + \
			(KEY % "Y") + "/" + (KEY % "N") + " help request   " + (KEY % "Esc") + " pause\n" + \
			"[color=#9aa4b8]Full list: HOW TO PLAY on the title screen.[/color]"
	# text sizes: every label / switch in the list
	for node in vbox.find_children("*", "", true, false):
		if node is RichTextLabel:
			node.add_theme_font_size_override("normal_font_size", UiScale.font(vp, 15))
			node.add_theme_font_size_override("bold_font_size", UiScale.font(vp, 15))
		elif node is Label or node is Button:
			var base: int = 13 if node.name == "Hint" else 16
			if node.name == "Title" or node.name.ends_with("Title"):
				base = 18
			node.add_theme_font_size_override("font_size", UiScale.font(vp, base))
	reset_button.custom_minimum_size.y = UiScale.touch_target(vp, 36.0)
	var close_button: Control = vbox.get_node("Header/CloseButton")
	close_button.custom_minimum_size = Vector2.ONE * UiScale.touch_target(vp, 36.0)
	var size := UiScale.modal_size(vp, Vector2(0.8, 0.92), Vector2(520, 580))
	$Center/Panel.custom_minimum_size = Vector2(size.x, 0)
	var scroll: ScrollContainer = vbox.get_parent()
	scroll.custom_minimum_size = Vector2(0, minf(vbox.get_combined_minimum_size().y, size.y - 120))


func open() -> void:
	# show the saved values (set_*_no_signal so this doesn't save again)
	music_on.set_pressed_no_signal(Sound.music_on)
	music_slider.set_value_no_signal(Sound.music_percent)
	sfx_on.set_pressed_no_signal(Sound.sfx_on)
	sfx_slider.set_value_no_signal(Sound.sfx_percent)
	touch_on.set_pressed_no_signal(GameState.touch_controls)
	vibration_on.set_pressed_no_signal(GameState.vibration)
	fps_on.set_pressed_no_signal(GameState.show_fps)
	_reset_armed = false
	reset_button.text = "Reset my data"
	# no resetting in the middle of a round
	reset_button.disabled = GameState.round_state != GameState.RoundState.READY \
		and get_tree().current_scene.name == "MazeGame"
	_update_labels()
	_apply_platform()
	visible = true


func close() -> void:
	visible = false


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "Tap again to confirm"
		return
	GameState.reset_all_data()
	open()   # show the default values
	reset_button.text = "Data cleared"
	if get_tree().current_scene.has_method("_normalize_player_name"):
		get_tree().current_scene._normalize_player_name()


func _music_changed() -> void:
	Sound.set_music(music_on.button_pressed, int(music_slider.value))
	_update_labels()


func _sfx_changed() -> void:
	Sound.set_sfx(sfx_on.button_pressed, int(sfx_slider.value))
	_update_labels()


func _update_labels() -> void:
	music_value.text = "%d%%" % music_slider.value
	sfx_value.text = "%d%%" % sfx_slider.value
	music_slider.editable = music_on.button_pressed
	sfx_slider.editable = sfx_on.button_pressed
	music_slider.modulate.a = 1.0 if music_on.button_pressed else 0.4
	sfx_slider.modulate.a = 1.0 if sfx_on.button_pressed else 0.4


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()   # a click outside the window closes it


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()   # so Esc doesn't also pause the game
