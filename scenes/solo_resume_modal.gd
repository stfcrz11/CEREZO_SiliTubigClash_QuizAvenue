extends Control
## "SOLO GAME FOUND" window: shown before SOLO VS BOT when a saved game
## (data/solo_save.gd) is past Round 1. The player MUST pick one:
##   RESUME    -> a fresh round at the saved round number
##   NEW GAME  -> Round 1 (replaces the save)
## No ✕, and tapping outside does nothing. Esc / the Android Back button
## goes back to the PLAY window without starting a game.
## Same sari-sari store look as Host / Join (scenes/pixel_store.gd).

signal resume_chosen
signal new_game_chosen
signal back

const PixelStore := preload("res://scenes/pixel_store.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const SoloSave := preload("res://data/solo_save.gd")

var _w: Dictionary
var _last_played: Label
var _saved_when: Label
var _resume: Button
var _new_game: Button
var _warning: Label


func _ready() -> void:
	name = "SoloResumeModal"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill the parent (a new Control has no size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_w = PixelStore.build_modal("blue", "blue", "SOLO GAME FOUND", false, false)
	add_child(_w["root"])
	var content: VBoxContainer = _w["content"]
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	_last_played = PixelStore.label("", 20, Color(0.5, 0.12, 0.08))   # dark red on the plaster wall
	_last_played.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_last_played)
	_saved_when = PixelStore.label("", 16, Color(0.3, 0.32, 0.4))
	_saved_when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_saved_when)
	var buttons: HBoxContainer = _w["buttons"]
	_resume = PixelUI.button("RESUME", "primary", 64, 32)
	_resume.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # same height as NEW GAME
	buttons.add_child(_resume)
	var new_box := VBoxContainer.new()
	buttons.add_child(new_box)
	_new_game = PixelUI.button("NEW GAME", "secondary", 64, 32)
	new_box.add_child(_new_game)
	_warning = PixelStore.label("Starts over from Round 1", 16, Color(1, 0.9, 0.75))
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	_warning.add_theme_constant_override("outline_size", 4)
	new_box.add_child(_warning)
	_resume.pressed.connect(_pick.bind(resume_chosen))
	_new_game.pressed.connect(_pick.bind(new_game_chosen))
	get_viewport().size_changed.connect(_layout)


func open(save: Dictionary) -> void:
	_last_played.text = "Last played: %s" % SoloSave.describe(save)
	var when: int = save.get("saved_at", 0)
	_saved_when.text = ("Saved %s" % Time.get_datetime_string_from_unix_time(
		when + int(Time.get_time_zone_from_system().get("bias", 0)) * 60, true)) if when > 0 else ""
	_saved_when.visible = when > 0
	(_w["status"] as Label).text = "Your Solo vs Bot progress is saved on this device."
	visible = true
	_layout()
	PixelStore.drop_in(_w["center"], get_viewport())


func is_open() -> bool:
	return visible


func _pick(choice: Signal) -> void:
	if not visible:
		return
	visible = false
	choice.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false          # Back: return to the PLAY window, start nothing
		get_viewport().set_input_as_handled()
		back.emit()


func _layout() -> void:
	if not visible:
		return
	var vp := get_viewport()
	var m := PixelStore.fit(_w, vp, 0.0, 860.0)
	_last_played.add_theme_font_size_override("font_size", m["body"] + 4)
	_saved_when.add_theme_font_size_override("font_size", m["hint"])
	_warning.add_theme_font_size_override("font_size", m["hint"])
	var font := PixelUI.pixel_size(m["title"])
	for b in [_resume, _new_game]:
		b.custom_minimum_size = Vector2(maxf(240.0, m["vh"] * 0.42), maxf(m["button"], 72.0))
		b.add_theme_font_size_override("font_size", font)
	var content: Control = _w["content"]
	content.custom_minimum_size.y = m["row"] * 1.6
