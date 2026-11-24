extends SceneTree
# v1.3 HUD + pause menu screenshots. OUT=<folder>, TAG=<name>
#   godot --path . --resolution 2340x1080 --script tools/tests/shot_hud.gd  (SILITUBIG_MOBILE_UI=1 for phone mode)
var game
var frames := 0
var t_play := -1
var out := OS.get_environment("OUT")
var tag := OS.get_environment("TAG")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	root.get_node("Network").play_solo(true, 1)
	change_scene_to_file("res://scenes/maze_game.tscn")

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, tag, n])
	print("shot ", n)

func _process(_d: float) -> bool:
	frames += 1
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		return false
	var gs = root.get_node("GameState")
	if t_play < 0 and gs.round_state == gs.RoundState.PLAYING:
		t_play = frames
	if t_play < 0:
		return frames > 60 * 30
	var f := frames - t_play
	if f == 90:
		_shot("hud")
	if f == 100:
		game._on_pause_pressed()
		print("paused: ", gs.round_state == gs.RoundState.PAUSED, " menu: ", game.settings_panel.visible)
	if f == 130:
		_shot("menu")
	if f == 140:
		game.settings_panel._show_how_to(true)
	if f == 170:
		_shot("help")
	if f == 180:
		game.settings_panel._show_how_to(false)
		game.settings_panel.close()
		print("after close: playing=", gs.round_state == gs.RoundState.PLAYING, " menu: ", game.settings_panel.visible)
	if f == 190:
		var t = game.tubigs[0]
		t.set_caught()
		game._update_hud()
	if f == 220:
		_shot("frozen")
		return true
	return false
