extends Control
## Title screen: Play, How to Play, Leaderboard, Credits, Quit.
## The ProfileCard (top-left) shows the player name; clicking it opens the
## CHANGE PLAYER NAME window (NamePopup: SAVE, CANCEL, X, Esc, click outside).
## The background is the pixel city (title_runners.gd animates the kids).
## PLAY opens the PLAY window (close: X, Esc, or click outside) with:
##   SOLO VS BOT  -> you (Tubig) vs Bot Silis. If a saved Solo game is past
##                   Round 1, the SOLO GAME FOUND window (solo_resume_modal.gd)
##                   asks RESUME or NEW GAME first (data/solo_save.gd).
##   HOST GAME    -> opens HostModal (host_modal.tscn)
##   JOIN GAME    -> opens JoinModal (join_modal.tscn)
## The title and the buttons are PNG pictures in assets/ui/ — replace those
## files (or drag new ones into the Inspector) to change how they look.
## LEADERBOARD opens the TOP PLAYERS window (scenes/leaderboard_modal.gd,
## built in code in the same store look as Host / Join; close: X, Esc, or
## click outside). It shows the leaderboard saved on this device.

const HowToPlay := preload("res://data/how_to_play.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const UiScale := preload("res://scenes/ui_scale.gd")
const SoloSave := preload("res://data/solo_save.gd")
const LeaderboardModal := preload("res://scenes/leaderboard_modal.gd")
const SoloResumeModal := preload("res://scenes/solo_resume_modal.gd")

var leaderboard: LeaderboardModal     # TOP PLAYERS window
var resume_modal: SoloResumeModal   # SOLO GAME FOUND window
var _name_kb_shift: float = 0.0     # how far the name window is moved up for the phone keyboard


func _ready() -> void:
	leaderboard = LeaderboardModal.new()
	add_child(leaderboard)
	leaderboard.problem.connect(func(msg: String): $Menu/ErrorLabel.text = msg)
	resume_modal = SoloResumeModal.new()
	add_child(resume_modal)
	resume_modal.resume_chosen.connect(_on_resume_solo)
	resume_modal.new_game_chosen.connect(_on_new_solo)
	resume_modal.back.connect(_show_play.bind(true))
	# profile card (top-left) -> CHANGE PLAYER NAME window
	$ProfileCard/HBox/NameLabel.text = GameState.player_name
	# after "Reset my data" show "Player" at once, not only after a restart (D-08)
	GameState.data_reset.connect(_on_data_reset)
	$ProfileCard.pressed.connect(_show_name_popup.bind(true))
	$NamePopup/Margin/VBox/Header/CloseButton.pressed.connect(_show_name_popup.bind(false))
	$NamePopup/Margin/VBox/Buttons/CancelButton.pressed.connect(_show_name_popup.bind(false))
	$NamePopup/Margin/VBox/Buttons/SaveButton.pressed.connect(_save_player_name)
	$NamePopup/Margin/VBox/NameInput.text_submitted.connect(func(_t): _save_player_name())
	$NamePopup/Margin/VBox/NameInput.text_changed.connect(func(_t): _set_name_hint(""))
	$NameDim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show_name_popup(false))
	$Menu/PlayButton.pressed.connect(_show_play.bind(true))
	$PlayPanel/Margin/VBox/Header/CloseButton.pressed.connect(_show_play.bind(false))
	$PlayDim.gui_input.connect(_on_play_dim_input)
	$PlayPanel/Margin/VBox/SoloButton.pressed.connect(_start_solo)
	$PlayPanel/Margin/VBox/HostButton.pressed.connect(_open_lan_window.bind($HostModal))
	$PlayPanel/Margin/VBox/JoinButton.pressed.connect(_open_lan_window.bind($JoinModal))
	$Menu/HowToButton.pressed.connect(_show_how_to.bind(true))
	$Menu/QuitButton.pressed.connect(func(): get_tree().quit())
	$Menu/CreditsButton.pressed.connect(_show_credits.bind(true))
	$CreditsPanel/Margin/VBox/CloseButton.pressed.connect(_show_credits.bind(false))
	$CreditsDim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _show_credits(false))
	$VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version", "1.0")
	# finger scrolling + a wide scrollbar for the long windows
	for scroll in [$HowToPanel/Margin/VBox/Scroll, $CreditsPanel/Margin/VBox/Scroll]:
		TouchScroll.setup(scroll)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	GameState.reset_question_decks()   # back on the title screen = a new game session
	$HowToPanel/Margin/VBox/CloseButton.pressed.connect(_show_how_to.bind(false))
	$Menu/LeaderboardButton.pressed.connect(_show_leaderboard.bind(true))
	$SettingsButton.pressed.connect(func(): $SettingsPanel.open())
	_show_how_to(false)
	_show_leaderboard(false)
	_show_play(false)
	_show_credits(false)
	_show_name_popup(false)
	Sound.play_music("title")   # keeps playing if it already is
	get_tree().paused = false
	# show why we came back here (e.g. the host left)
	$Menu/ErrorLabel.text = Network.last_error
	Network.last_error = ""


## Open / close the CHANGE PLAYER NAME window. It always opens with the
## saved name, so CANCEL / X / Esc / a click outside throw away any typing.
func _show_name_popup(open: bool) -> void:
	$NamePopup.visible = open
	$NameDim.visible = open
	_set_name_hint("")
	if open:
		var input: LineEdit = $NamePopup/Margin/VBox/NameInput
		# Android: the keyboard copies the field when focus starts and counts
		# letters it was given against max_length, so with "Player" in the
		# field only 12 - 6 = 6 new letters fit even after deleting it (D-11).
		# Open the keyboard on an EMPTY field, then put the saved name in.
		input.text = ""
		input.grab_focus()
		input.text = GameState.player_name
		input.caret_column = input.text.length()


func _on_data_reset() -> void:
	$ProfileCard/HBox/NameLabel.text = GameState.player_name


func _save_player_name() -> void:
	# only valid names are saved; otherwise the reason replaces the hint
	var value: String = $NamePopup/Margin/VBox/NameInput.text
	var problem := GameState.name_problem(value)
	if not problem.is_empty():
		_set_name_hint(problem)
		return
	GameState.set_player_name(value)   # saves to user:// (existing save system)
	$ProfileCard/HBox/NameLabel.text = GameState.player_name
	_show_name_popup(false)


func _set_name_hint(problem: String) -> void:
	var hint: Label = $NamePopup/Margin/VBox/Hint
	hint.text = problem if not problem.is_empty() else "Max 12 characters"
	hint.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if not problem.is_empty() else Color(0.62, 0.66, 0.76))


func _show_play(open: bool) -> void:
	$PlayPanel.visible = open
	$PlayDim.visible = open
	var best := GameState.best_solo_round
	$PlayPanel/Margin/VBox/SoloHint.text = "You are Tubig. 4 rounds, easy to hard: run from 1-3 Bot Silis!" + \
		("" if best == 0 else ("\nBest: cleared Round %d%s" % [best, " — all rounds!" if best >= 4 else ""]))


func _on_play_dim_input(event: InputEvent) -> void:
	# a click outside the window closes it
	if event is InputEventMouseButton and event.pressed:
		_show_play(false)


## SOLO VS BOT: ask RESUME / NEW GAME when a saved game is past Round 1,
## otherwise start Round 1 right away.
func _start_solo() -> void:
	var save := SoloSave.load_save(SoloSave.DEFAULT_MAP)
	if save.get("round", 1) > 1:
		_show_play(false)
		resume_modal.open(save)
		return
	_begin_solo(1)


func _on_resume_solo() -> void:
	var save := SoloSave.load_save(SoloSave.DEFAULT_MAP)
	_begin_solo(save.get("round", 1))


func _on_new_solo() -> void:
	SoloSave.save_round(1, SoloSave.DEFAULT_MAP)   # NEW GAME replaces the save
	_begin_solo(1)


func _begin_solo(round: int) -> void:
	Network.play_solo(true, round)   # you (Tubig) vs the Bot Silis
	get_tree().change_scene_to_file(GameState.GAME_SCENE)


func _open_lan_window(window: Control) -> void:
	_show_play(false)
	window.open()


func _show_leaderboard(open: bool) -> void:
	if open:
		leaderboard.open()   # always shows the latest results
	else:
		leaderboard.close()


## Window sizes and text sizes for this screen (bigger on phones, inside
## the safe area). Runs again when the window is resized or rotated.
func _apply_layout() -> void:
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	_fit($HowToPanel, UiScale.modal_size(vp, Vector2(0.9, 0.92), Vector2(660, 500)))
	_fit($CreditsPanel, UiScale.modal_size(vp, Vector2(0.9, 0.92), Vector2(680, 540)))
	var body := UiScale.font(vp, 15)
	var rules: RichTextLabel = $HowToPanel/Margin/VBox/Scroll/Rules
	for key in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		rules.add_theme_font_size_override(key, body)
	rules.custom_minimum_size.x = 0
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.text = HowToPlay.text(mobile, UiScale.font(vp, 19))
	$HowToPanel/Margin/VBox/Scroll.custom_minimum_size = Vector2(0, 0)
	$HowToPanel/Margin/VBox/Scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var credits: RichTextLabel = $CreditsPanel/Margin/VBox/Scroll/Text
	for key in ["normal_font_size", "bold_font_size"]:
		credits.add_theme_font_size_override(key, body)
	for header in [$HowToPanel/Margin/VBox/Header, $CreditsPanel/Margin/VBox/Header]:
		header.add_theme_font_size_override("font_size", UiScale.font(vp, 28))
	var k := UiScale.touch_target(vp, 50.0) / 50.0
	for close in [$HowToPanel/Margin/VBox/CloseButton, $CreditsPanel/Margin/VBox/CloseButton]:
		close.custom_minimum_size = Vector2(200, 50) * k
	$Menu/ErrorLabel.add_theme_font_size_override("font_size", UiScale.font(vp, 15))
	$VersionLabel.add_theme_font_size_override("font_size", UiScale.font(vp, 14))
	_fit($NamePopup, UiScale.modal_size(vp, Vector2(0.6, 0.8), Vector2(400, 300)))
	$ProfileCard/HBox/NameLabel.add_theme_font_size_override("font_size", UiScale.font(vp, 18))
	$NamePopup/Margin/VBox/Header/Title.add_theme_font_size_override("font_size", UiScale.font(vp, 22))
	$NamePopup/Margin/VBox/NameInput.add_theme_font_size_override("font_size", UiScale.font(vp, 16))


## Centre a window with the given size.
func _fit(panel: Control, size: Vector2) -> void:
	panel.offset_left = -size.x / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_bottom = size.y / 2.0
	if panel == $NamePopup:
		_name_kb_shift = 0.0   # freshly centred: no keyboard shift applied


func _process(delta: float) -> void:
	if $NamePopup.visible or _name_kb_shift != 0.0:
		_name_follow_keyboard(delta)


## Phones: when the on-screen keyboard is up, slide the CHANGE PLAYER NAME
## window up so the name box and SAVE / CANCEL stay above the keyboard
## (in landscape the keyboard covered them). Slides back when it closes.
func _name_follow_keyboard(delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and _name_kb_shift == 0.0:
		return   # PC: no on-screen keyboard
	var kb_px := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		kb_px = float(DisplayServer.virtual_keyboard_get_height())
	var input: LineEdit = $NamePopup/Margin/VBox/NameInput
	var target := 0.0
	if kb_px > 0.0 and $NamePopup.visible and input.has_focus():
		var vp := get_viewport()
		var kb := kb_px / UiScale.content_scale(vp)   # screen pixels -> UI units
		var buttons: Control = $NamePopup/Margin/VBox/Buttons
		var bottom := buttons.get_global_rect().end.y + _name_kb_shift   # without the shift
		var free_bottom := vp.get_visible_rect().size.y - kb - 12.0
		var input_top := input.get_global_rect().position.y + _name_kb_shift
		target = clampf(bottom - free_bottom, 0.0, maxf(0.0, input_top - 8.0))
	var new_shift := lerpf(_name_kb_shift, target, minf(1.0, delta * 14.0))
	if absf(new_shift - target) < 0.5:
		new_shift = target
	# move both offsets by the change (keeps the size from _fit)
	var step := new_shift - _name_kb_shift
	$NamePopup.offset_top -= step
	$NamePopup.offset_bottom -= step
	_name_kb_shift = new_shift


func _show_credits(open: bool) -> void:
	$CreditsPanel.visible = open
	$CreditsDim.visible = open


func _show_how_to(open: bool) -> void:
	$HowToPanel.visible = open
	$HowToDim.visible = open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if $NamePopup.visible:
		_show_name_popup(false)
		get_viewport().set_input_as_handled()
	elif $PlayPanel.visible:
		_show_play(false)
		get_viewport().set_input_as_handled()
	elif $HowToPanel.visible:
		_show_how_to(false)
		get_viewport().set_input_as_handled()
	elif $CreditsPanel.visible:
		_show_credits(false)
		get_viewport().set_input_as_handled()
