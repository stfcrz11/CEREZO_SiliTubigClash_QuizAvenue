extends Control
## SETTINGS window: the gear button on the title screen, the pause button in game.
## Music / Sound effects: on-off switch + volume slider (saved on this
## device by the Sound autoload). CONTROLS: the list of keys.
## Close with the X, Esc, or a click outside. maze_game.gd decides what pauses.
## To customize: open scenes/settings_panel.tscn and click any node.
## Phones only: the touch-controls and vibration switches, touch wording in
## the controls list, bigger text. Desktop: keyboard wording, no joystick
## switch. The window scrolls if it doesn't fit.
## In the game it is also the PAUSE menu (open_menu()): HELP opens the How
## to Play window, LEAVE asks maze_game.gd to show the LEAVE GAME? window.

const UiScale := preload("res://scenes/ui_scale.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const KEY := "[bgcolor=#33405e][color=#ffffff][b] %s [/b][/color][/bgcolor]"
const PixelUI := preload("res://scenes/pixel_ui.gd")
const ButtonStyle := preload("res://scenes/ui_button_style.gd")
const HowToPlay := preload("res://data/how_to_play.gd")

signal closed            # the window was closed (X, Esc, click outside)
signal leave_pressed     # in-game menu: LEAVE was pressed

@onready var music_on: CheckButton = $Center/Panel/Margin/VBox/MusicRow/On
@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/MusicRow/Slider
@onready var music_value: Label = $Center/Panel/Margin/VBox/MusicRow/Value
@onready var sfx_on: CheckButton = $Center/Panel/Margin/VBox/SfxRow/On
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value: Label = $Center/Panel/Margin/VBox/SfxRow/Value
@onready var touch_on: CheckButton = $Center/Panel/Margin/VBox/TouchRow/On
@onready var layout_normal: Button = $Center/Panel/Margin/VBox/SwitchRow/Normal     # joystick right
@onready var layout_swapped: Button = $Center/Panel/Margin/VBox/SwitchRow/Swapped   # joystick left
@onready var vibration_on: CheckButton = $Center/Panel/Margin/VBox/VibrationRow/On
@onready var fps_on: CheckButton = $Center/Panel/Margin/VBox/FpsRow/On
@onready var reset_button: Button = $Center/Panel/Margin/VBox/ResetRow/ResetButton
var _reset_armed := false   # Reset needs two taps, so it can't happen by accident
# in-game pause menu (built in code, hidden on the title screen)
var _game_box: VBoxContainer
var _note_label: Label
var _help_button: Button
var _leave_button: Button
var _how_to: Control         # the How to Play window opened by HELP
var _how_to_panel: PanelContainer
var _how_to_title: Label
var _how_to_scroll: ScrollContainer
var _how_to_text: RichTextLabel


func _ready() -> void:
	visible = false
	$Center/Panel/Margin/VBox/Header/CloseButton.pressed.connect(close)
	$Dim.gui_input.connect(_on_dim_input)
	music_on.toggled.connect(func(_on): _music_changed())
	music_slider.value_changed.connect(func(_v): _music_changed())
	sfx_on.toggled.connect(func(_on): _sfx_changed())
	sfx_slider.value_changed.connect(func(_v): _sfx_changed())
	touch_on.toggled.connect(func(on): GameState.set_touch_controls(on))
	layout_normal.pressed.connect(_set_layout.bind(false))
	layout_swapped.pressed.connect(_set_layout.bind(true))
	vibration_on.toggled.connect(func(on): GameState.set_vibration(on))
	fps_on.toggled.connect(func(on): GameState.set_show_fps(on))
	reset_button.pressed.connect(_on_reset)
	ButtonStyle.style_secondary(reset_button, Color(0.72, 0.22, 0.18))
	_make_scrollable()
	_build_game_box()
	_build_how_to()


## Puts the settings list in a ScrollContainer (big phone text may not fit).
func _make_scrollable() -> void:
	var vbox: Control = $Center/Panel/Margin/VBox
	var margin := vbox.get_parent()
	margin.remove_child(vbox)
	var outer := VBoxContainer.new()
	outer.name = "Outer"
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	outer.add_child(scroll)
	scroll.add_child(vbox)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TouchScroll.setup(scroll)


## In-game only: a divider, a note line and the HELP / LEAVE buttons,
## under the scrolling list so they are always visible.
func _build_game_box() -> void:
	_game_box = VBoxContainer.new()
	_game_box.name = "GameBox"
	_game_box.add_theme_constant_override("separation", 10)
	_game_box.visible = false
	$Center/Panel/Margin/Outer.add_child(_game_box)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(1, 0.82, 0.3, 0.5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_box.add_child(line)
	_note_label = Label.new()
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_color_override("font_color", Color(0.62, 0.85, 1.0))
	_game_box.add_child(_note_label)
	_help_button = PixelUI.button("HELP", "primary", 44, 16)
	_help_button.pressed.connect(_show_how_to.bind(true))
	_leave_button = PixelUI.button("LEAVE", "danger", 44, 16)
	_leave_button.pressed.connect(func(): leave_pressed.emit())
	# side by side, so the settings list keeps its room on a landscape phone
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_game_box.add_child(row)
	for b in [_help_button, _leave_button]:
		row.add_child(b)


## The HOW TO PLAY window (same text as the title screen's, data/how_to_play.gd).
func _build_how_to() -> void:
	_how_to = Control.new()
	_how_to.name = "HowTo"
	_how_to.set_anchors_preset(Control.PRESET_FULL_RECT)
	_how_to.visible = false
	add_child(_how_to)
	_how_to.add_child(PixelUI.dim(0.5))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_how_to.add_child(center)
	_how_to_panel = PanelContainer.new()
	_how_to_panel.add_theme_stylebox_override("panel", PixelUI.panel_style())
	center.add_child(_how_to_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_how_to_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	_how_to_title = Label.new()
	_how_to_title.text = "HOW TO PLAY"
	_how_to_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_how_to_title.add_theme_color_override("font_color", Color(1, 0.82, 0.3))
	_how_to_title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_how_to_title.add_theme_constant_override("outline_size", 7)
	vbox.add_child(_how_to_title)
	_how_to_scroll = ScrollContainer.new()
	_how_to_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_how_to_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_how_to_scroll)
	_how_to_text = RichTextLabel.new()
	_how_to_text.bbcode_enabled = true
	_how_to_text.fit_content = true
	_how_to_text.scroll_active = false
	_how_to_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_how_to_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_how_to_scroll.add_child(_how_to_text)
	TouchScroll.setup(_how_to_scroll)
	var back := PixelUI.button("BACK", "secondary", 44, 16)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_how_to.bind(false))
	vbox.add_child(back)


func _show_how_to(open: bool) -> void:
	_how_to.visible = open
	if not open:
		return
	var vp := get_viewport()
	_how_to_panel.custom_minimum_size = UiScale.modal_size(vp, Vector2(0.9, 0.92), Vector2(660, 500))
	var body := UiScale.font(vp, 15)
	for key in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_how_to_text.add_theme_font_size_override(key, body)
	_how_to_text.text = HowToPlay.text(GameState.is_mobile_ui(), UiScale.font(vp, 19))
	_how_to_title.add_theme_font_size_override("font_size", UiScale.font(vp, 24))
	_how_to_scroll.scroll_vertical = 0


## Platform-specific rows and wording, and text sizes for this screen.
func _apply_platform() -> void:
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	var vbox: Control = music_on.get_parent().get_parent()
	vbox.get_node("TouchRow").visible = mobile
	vbox.get_node("SwitchRow").visible = mobile
	# vibration is listed everywhere, but only phones / tablets can buzz
	vibration_on.disabled = not mobile
	vibration_on.modulate.a = 1.0 if mobile else 0.4
	vbox.get_node("VibrationRow/Hint").text = "phone buzzes when you are tagged or answer" if mobile \
		else "phones and tablets only"
	for b in [layout_normal, layout_swapped]:
		b.custom_minimum_size.y = UiScale.touch_target(vp, 40.0)
	var controls: RichTextLabel = vbox.get_node("Controls")
	if mobile:
		controls.text = "Drag the [b]" + ("left" if GameState.swap_controls else "right") + " half[/b] to move · hold [b]RUN[/b] to sprint · tap [b]USE[/b] at a station\n" + \
			"Tap an answer · tap [b]YES / NO[/b] for help · [b]pause[/b] / [b]Back[/b] = this menu\n" + \
			"[color=#9aa4b8]Full list: HOW TO PLAY on the title screen.[/color]"
	else:
		controls.text = (KEY % "W A S D") + " move   " + (KEY % "Shift") + " sprint   " + (KEY % "E") + " use a station\n" + \
			(KEY % "A") + (KEY % "B") + (KEY % "C") + (KEY % "D") + " answer   " + (KEY % "H") + " help   " + \
			(KEY % "Y") + "/" + (KEY % "N") + " help request   " + (KEY % "Esc") + " this menu\n" + \
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
	var reserved := 120.0
	if _game_box.visible:
		var bh := UiScale.touch_target(vp, 44.0)
		for b in [_help_button, _leave_button]:
			b.custom_minimum_size = Vector2(bh * 3.5, bh)
			b.add_theme_font_size_override("font_size", UiScale.font(vp, 16))
		_note_label.add_theme_font_size_override("font_size", UiScale.font(vp, 14))
		reserved += _game_box.get_combined_minimum_size().y + 12.0
	scroll.custom_minimum_size = Vector2(0, maxf(80.0, minf(vbox.get_combined_minimum_size().y, size.y - reserved)))


## In-game pause menu: the settings plus HELP (and LEAVE when allowed).
## note: a line under the divider (e.g. "The host paused the game"), "" = none.
func open_menu(note: String, show_leave: bool) -> void:
	_game_box.visible = true
	_note_label.text = note
	_note_label.visible = note != ""
	_leave_button.visible = show_leave
	open()


## Title screen: settings only.
func open() -> void:
	# show the saved values (set_*_no_signal so this doesn't save again)
	music_on.set_pressed_no_signal(Sound.music_on)
	music_slider.set_value_no_signal(Sound.music_percent)
	sfx_on.set_pressed_no_signal(Sound.sfx_on)
	sfx_slider.set_value_no_signal(Sound.sfx_percent)
	touch_on.set_pressed_no_signal(GameState.touch_controls)
	vibration_on.set_pressed_no_signal(GameState.vibration)
	_show_layout()
	fps_on.set_pressed_no_signal(GameState.show_fps)
	_reset_armed = false
	reset_button.text = "Reset my data"
	# no resetting in the middle of a round
	reset_button.disabled = GameState.round_state != GameState.RoundState.READY \
		and get_tree().current_scene.name == "MazeGame"
	_update_labels()
	_apply_platform()
	visible = true


## Controls layout: two choices, the chosen one is gold.
func _set_layout(swapped: bool) -> void:
	GameState.set_swap_controls(swapped)
	_show_layout()
	_apply_platform()   # the controls text names the joystick side


func _show_layout() -> void:
	for b in [layout_normal, layout_swapped]:
		var chosen: bool = (b == layout_swapped) == GameState.swap_controls
		if chosen:
			ButtonStyle.style_primary(b)
		else:
			ButtonStyle.style_secondary(b, Color(0.3, 0.33, 0.42))


func close() -> void:
	if not visible:
		return
	visible = false
	_how_to.visible = false
	_game_box.visible = false
	closed.emit()


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
		if _how_to.visible:
			_show_how_to(false)   # Esc closes How to Play first
		else:
			close()
		get_viewport().set_input_as_handled()   # so Esc doesn't also pause the game
