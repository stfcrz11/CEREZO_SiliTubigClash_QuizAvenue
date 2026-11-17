extends Control
## Title screen: Play, How to Play, Leaderboard, Credits, Quit.
## The background is the pixel city (title_runners.gd animates the kids).
## PLAY opens the PLAY window (close: X, Esc, or click outside) with:
##   SOLO VS BOT  -> starts a round right away: you (Tubig) vs a Bot Sili
##   HOST GAME    -> opens HostModal (host_modal.tscn)
##   JOIN GAME    -> opens JoinModal (join_modal.tscn)
## The title and the buttons are PNG pictures in assets/ui/ — replace those
## files (or drag new ones into the Inspector) to change how they look.
## LEADERBOARD opens the TOP PLAYERS window (close: X, Esc, or click outside).
## It shows the leaderboard saved on this device
## (data/leaderboard.gd). Leaderboard/.../Rows/RowTemplate is ONE row: the
## script copies it for every player, so edit it to change every row.

const Leaderboard := preload("res://data/leaderboard.gd")
const HowToPlay := preload("res://data/how_to_play.gd")
const TouchScroll := preload("res://scenes/touch_scroll.gd")
const UiScale := preload("res://scenes/ui_scale.gd")
const MAX_ROWS := 20
const RANK_COLORS := [Color(1, 0.82, 0.3), Color(0.8, 0.84, 0.9), Color(0.85, 0.55, 0.3)]   # gold, silver, bronze


func _ready() -> void:
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name
	$Menu/PlayerNameRow/PlayerNameInput.text_changed.connect(_on_player_name_changed)
	$Menu/PlayerNameRow/PlayerNameInput.focus_exited.connect(_normalize_player_name)
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
	for scroll in [$HowToPanel/Margin/VBox/Scroll, $CreditsPanel/Margin/VBox/Scroll, $Leaderboard/Margin/VBox/Scroll]:
		TouchScroll.setup(scroll)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	GameState.reset_question_decks()   # back on the title screen = a new game session
	$HowToPanel/Margin/VBox/CloseButton.pressed.connect(_show_how_to.bind(false))
	$Menu/LeaderboardButton.pressed.connect(_show_leaderboard.bind(true))
	$Leaderboard/Margin/VBox/Header/CloseButton.pressed.connect(_show_leaderboard.bind(false))
	$LeaderboardDim.gui_input.connect(_on_leaderboard_dim_input)
	$SettingsButton.pressed.connect(func(): $SettingsPanel.open())
	_show_how_to(false)
	_show_leaderboard(false)
	_show_play(false)
	_show_credits(false)
	Sound.play_music("title")   # keeps playing if it already is
	get_tree().paused = false
	# show why we came back here (e.g. the host left)
	$Menu/ErrorLabel.text = Network.last_error
	Network.last_error = ""


func _on_player_name_changed(value: String) -> void:
	# only valid names are saved; the reason is shown under the menu
	var problem := GameState.name_problem(value)
	$Menu/ErrorLabel.text = problem
	if problem.is_empty():
		GameState.set_player_name(value)


func _normalize_player_name() -> void:
	# an invalid name is replaced by the last saved one
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name
	$Menu/ErrorLabel.text = ""


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


func _start_solo() -> void:
	Network.play_solo(true)   # you (Tubig) vs the Bot Sili
	get_tree().change_scene_to_file(GameState.GAME_SCENE)


func _open_lan_window(window: Control) -> void:
	_show_play(false)
	window.open()


func _show_leaderboard(open: bool) -> void:
	if open:
		_fill_leaderboard()   # always show the latest results
	$Leaderboard.visible = open
	$LeaderboardDim.visible = open


func _on_leaderboard_dim_input(event: InputEvent) -> void:
	# a click outside the window closes it
	if event is InputEventMouseButton and event.pressed:
		_show_leaderboard(false)


func _fill_leaderboard() -> void:
	var rows: VBoxContainer = $Leaderboard/Margin/VBox/Scroll/Rows
	var template: Control = rows.get_node("RowTemplate")
	template.visible = false   # the template is copied, never shown
	for old in rows.get_children():
		if old != template:
			old.queue_free()
	var ranking := Leaderboard.rankings()
	if not Leaderboard.last_problem.is_empty():
		$Menu/ErrorLabel.text = Leaderboard.last_problem
		Leaderboard.last_problem = ""
	$Leaderboard/Margin/VBox/Empty.visible = ranking.is_empty()
	for i in min(ranking.size(), MAX_ROWS):
		var r: Dictionary = ranking[i]
		var row := template.duplicate()
		row.visible = true
		row.get_node("HBox/Rank").text = str(i + 1)
		row.get_node("HBox/Name").text = r["name"]
		row.get_node("HBox/Wins").text = str(r["wins"])
		row.get_node("HBox/Points").text = str(r["points"])
		var rank_color: Color = RANK_COLORS[i] if i < RANK_COLORS.size() else Color(0.62, 0.66, 0.76)
		row.get_node("HBox/Rank").add_theme_color_override("font_color", rank_color)
		if r["name"].to_lower() == GameState.player_name.to_lower():
			row.get_node("HBox/Name").add_theme_color_override("font_color", Color(1, 0.88, 0.35))   # you
		row.tooltip_text = "%s — %d games, %d wins, %d points" % [r["name"], r["games"], r["wins"], r["points"]]
		rows.add_child(row)


## Window sizes and text sizes for this screen (bigger on phones, inside
## the safe area). Runs again when the window is resized or rotated.
func _apply_layout() -> void:
	var vp := get_viewport()
	var mobile := GameState.is_mobile_ui()
	_fit($HowToPanel, UiScale.modal_size(vp, Vector2(0.9, 0.92), Vector2(660, 500)))
	_fit($CreditsPanel, UiScale.modal_size(vp, Vector2(0.9, 0.92), Vector2(680, 540)))
	_fit($Leaderboard, UiScale.modal_size(vp, Vector2(0.62, 0.92), Vector2(360, 490)))
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


## Centre a window with the given size.
func _fit(panel: Control, size: Vector2) -> void:
	panel.offset_left = -size.x / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_bottom = size.y / 2.0


func _show_credits(open: bool) -> void:
	$CreditsPanel.visible = open
	$CreditsDim.visible = open


func _show_how_to(open: bool) -> void:
	$HowToPanel.visible = open
	$HowToDim.visible = open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if $PlayPanel.visible:
		_show_play(false)
		get_viewport().set_input_as_handled()
	elif $HowToPanel.visible:
		_show_how_to(false)
		get_viewport().set_input_as_handled()
	elif $Leaderboard.visible:
		_show_leaderboard(false)
		get_viewport().set_input_as_handled()
	elif $CreditsPanel.visible:
		_show_credits(false)
		get_viewport().set_input_as_handled()
