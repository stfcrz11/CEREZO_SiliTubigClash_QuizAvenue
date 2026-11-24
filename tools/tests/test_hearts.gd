extends SceneTree
# v1.3 hearts: 3 freezes = OUT, solo end title, settings Layout row. OUT=<folder>, TAG=<name>
#   godot --path . --resolution 2340x1080 --script tools/tests/test_hearts.gd  (SILITUBIG_MOBILE_UI=1 for phone mode)
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
	var t = game.tubigs[0]
	match f:
		30:
			game._tubig_caught(t.peer_id)
			print("freeze 1: hearts=", 3 - t.freezes, " out=", t.out, " rescuable=", t.can_be_rescued(0.0))
		40:
			game._tubig_rescued(t.peer_id, true)
			game._tubig_caught(t.peer_id)
			print("freeze 2: hearts=", 3 - t.freezes, " out=", t.out)
		60:
			_shot("two_freezes")
		70:
			game._tubig_rescued(t.peer_id, true)
			game._tubig_caught(t.peer_id)
			print("freeze 3: hearts=", 3 - t.freezes, " out=", t.out, " rescuable=", t.can_be_rescued(0.0), " label=", t.name_label.text)
			game._host_check_team_out()
		120:
			print("round ended: ", gs.round_state == gs.RoundState.ENDED, " | ", game.end_panel.result_label.text)
			_shot("out")
			game.end_panel.visible = false
			game._open_menu()
		130:
			var scroll: ScrollContainer = game.settings_panel.get_node("Center/Panel/Margin/Outer/Scroll")
			scroll.scroll_vertical = 330
		150:
			_shot("settings_controls")
			game.settings_panel._set_layout(true)
		170:
			_shot("settings_swapped")
			print("swap saved: ", gs.swap_controls)
			game.settings_panel._set_layout(false)
			return true
	return false
