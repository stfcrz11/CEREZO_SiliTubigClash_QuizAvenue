extends Node
## Global singleton: current round state and scene paths. Also registers
## the movement keys (WASD or arrow keys, Space or Shift to sprint, E to
## use a power-up station) so
## no manual Input Map setup is needed. Every player uses the same keys
## on their own device. On phones, the on-screen joystick and RUN button
## (scenes/touch_controls.gd) press these same actions.

signal touch_controls_changed

enum RoundState { READY, PLAYING, QUESTION, PAUSED, ENDED }

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const GAME_SCENE := "res://scenes/maze_game.tscn"
const SETTINGS_PATH := "user://player_settings.cfg"

var round_state: RoundState = RoundState.READY
var player_name: String = "Player"
## On-screen joystick + RUN button. On by default on phones / touch screens,
## and never shown on desktop (see touch_controls_on()).
var touch_controls: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
var vibration: bool = true          # buzz the phone when tagged / answering
var show_fps: bool = false          # performance readout in the game (for testing)
var best_solo_round: int = 0        # highest SOLO VS BOT round cleared (0-4)


## Questions already shown this game session, per question list (host only).
## A session = from leaving the title screen until coming back to it: all
## Solo vs Bot rounds (retries too) or all rounds of a LAN match.
var _question_decks: Dictionary = {}    # list name -> indexes not used yet (shuffled)
var _last_question: Dictionary = {}     # list name -> the index shown last


## THE place that decides "phone / touch layout" vs "desktop layout": touch
## screens and Android builds are mobile. For testing on a PC, start Godot
## with the environment variable SILITUBIG_MOBILE_UI=1 (or 0 to force desktop).
static func is_mobile_ui() -> bool:
	var forced := OS.get_environment("SILITUBIG_MOBILE_UI")
	if forced == "1":
		return true
	if forced == "0":
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


## The joystick + RUN overlay is shown only on touch devices with it switched
## on (a stale saved "on" from a phone does nothing on a desktop).
func touch_controls_on() -> bool:
	return is_mobile_ui() and touch_controls


## Next question index from a list, never repeating within the game session.
## When every question of the list was used, a new shuffled cycle starts
## (the one shown last is never first again).
func next_question_index(list_name: String, list_size: int) -> int:
	var deck: Array = _question_decks.get(list_name, [])
	if deck.is_empty():
		if _question_decks.has(list_name):
			push_warning("Question list '%s' used up (%d questions): starting a new cycle." % [list_name, list_size])
		deck = range(list_size)
		deck.shuffle()
		var last: int = _last_question.get(list_name, -1)
		if deck.size() > 1 and deck.back() == last:
			deck.push_front(deck.pop_back())   # don't show the same question twice in a row
	var index: int = deck.pop_back()
	_question_decks[list_name] = deck
	_last_question[list_name] = index
	return index


## The local player's movement keys / joystick. After answering with A-D
## (A and D are also movement keys) movement is ignored until every movement
## key is let go, so the player doesn't walk off when the question closes.
var _moves_blocked: bool = false


func block_moves_until_released() -> void:
	_moves_blocked = true


func move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _moves_blocked:
		if v != Vector2.ZERO:
			return Vector2.ZERO
		_moves_blocked = false
	return v


## Start a fresh session: every question can be asked again.
func reset_question_decks() -> void:
	_question_decks.clear()
	_last_question.clear()


func _ready() -> void:
	_load_settings()
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT, KEY_SPACE])
	_add_keys("interact", [KEY_E])   # use a power-up station
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(a, 0.15)   # small joystick tilts still move


const NAME_MAX := 16

## Why a player name is not allowed ("" = it is fine). Names are shown to
## everyone and saved on the leaderboard, so they are kept short and plain.
static func name_problem(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		return "Please type a name."
	if cleaned.length() > NAME_MAX:
		return "Name is too long (max %d letters)." % NAME_MAX
	var allowed := RegEx.create_from_string("^[A-Za-z0-9 _.'ñÑ-]+$")
	if allowed.search(cleaned) == null:
		return "Use letters, numbers, spaces, - _ . ' only."
	return ""


## A safe version of any name (used for names received over LAN, too).
static func clean_name(value: String) -> String:
	var out := ""
	for ch in value.strip_edges():
		if name_problem(ch).is_empty() or ch == " ":
			out += ch
	out = out.strip_edges().left(NAME_MAX)
	return out if not out.is_empty() else "Player"


func set_player_name(value: String) -> void:
	player_name = clean_name(value)
	_save("player", "name", player_name)


func set_vibration(on: bool) -> void:
	vibration = on
	_save("controls", "vibration", on)


func set_show_fps(on: bool) -> void:
	show_fps = on
	_save("controls", "show_fps", on)


## Short phone vibration (haptic feedback). Does nothing on PC or when off.
func buzz(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func record_solo_clear(round: int) -> void:
	if round > best_solo_round:
		best_solo_round = round
		_save("solo", "best_round", round)


## "Reset my data": deletes everything this game saved on the device (name,
## settings, solo progress, leaderboard) and goes back to the defaults.
func reset_all_data() -> void:
	for path in [SETTINGS_PATH, "user://leaderboard.cfg", "user://leaderboard.cfg.bad", "user://solo_save.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	player_name = "Player"
	vibration = true
	show_fps = false
	best_solo_round = 0
	set_touch_controls(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))
	Sound.set_music(true, 80)
	Sound.set_sfx(true, 100)


func set_touch_controls(on: bool) -> void:
	touch_controls = on
	_save("controls", "touch", on)
	touch_controls_changed.emit()


func _save(section: String, key: String, value) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)   # keep the other saved settings (e.g. audio)
	settings.set_value(section, key, value)
	settings.save(SETTINGS_PATH)


func _load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	var saved_name = settings.get_value("player", "name", "Player")
	if saved_name is String:
		player_name = clean_name(saved_name)   # a hand-edited file can't break the game
	# every value is type-checked, so a damaged or hand-edited file can't crash the game
	var t = settings.get_value("controls", "touch", touch_controls)
	touch_controls = t if t is bool else touch_controls
	var v = settings.get_value("controls", "vibration", true)
	vibration = v if v is bool else true
	var f = settings.get_value("controls", "show_fps", false)
	show_fps = f if f is bool else false
	var b = settings.get_value("solo", "best_round", 0)
	best_solo_round = clampi(b, 0, 4) if b is int else 0


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _notification(what: int) -> void:
	# Android back button = Esc: closes windows, and the host can pause.
	# (project.godot has quit_on_go_back off, so it doesn't quit the app.)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed in [true, false]:
			var e := InputEventAction.new()
			e.action = "ui_cancel"
			e.pressed = pressed
			Input.parse_input_event(e)
