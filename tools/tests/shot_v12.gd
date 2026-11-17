extends SceneTree
# Screenshots of the v1.2 screens in one solo game. OUT=<folder>, TAG=<name>.
#   godot --path . --resolution 2400x1080 --script tools/tests/shot_v12.gd
# (set SILITUBIG_MOBILE_UI=1 for the phone layout)
var game
var frames := 0
var step := 0
var wait := 0
var out := OS.get_environment("OUT")
var tag := OS.get_environment("TAG")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	root.get_node("Network").play_solo(true, 2)
	change_scene_to_file("res://scenes/maze_game.tscn")

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, tag, n])

func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)

func _process(_d: float) -> bool:
	frames += 1
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		return false
	if wait > 0:
		wait -= 1
		return false
	var gs = root.get_node("GameState")
	match step:
		0:
			if game.tubigs.is_empty(): return false
			step = 1; wait = 200
		1:
			print("intro visible=", game.round_intro.visible, " a=", game.round_intro.modulate.a, " state=", gs.round_state, " role=", game.round_intro._role_label.text, " box=", game.round_intro._box.get_rect())
			_shot("intro")
			step = 2
		2:
			if gs.round_state != gs.RoundState.PLAYING: return false
			game.get_node("BotSili_991").set_physics_process(false)
			game.silis[0].force_position(game.cell_to_world(Vector2i(20, 7)))
			game.tubigs[0].force_position(game.scrolls.values()[0].position)
			step = 3; wait = 20
		3:
			_shot("hud_quiz")
			key(KEY_B)
			step = 4; wait = 4
		4:
			_shot("feedback")
			step = 5; wait = 75
		5:
			var ap = game.answer_popup; print("popup vis=", ap.visible, " rect=", ap.get_global_rect(), " center=", ap._center.get_rect(), " panel=", ap._panel.get_rect(), " scale=", ap._panel.scale, " mod=", ap.modulate, " open=", ap._open)
			_shot("popup")
			key(KEY_SPACE)
			step = 6; wait = 20
		6:
			game.answer_popup.open(false, true, "Stef", "Banaue Rice Terraces",
				"The Rice Terraces of the Philippine Cordilleras were carved by the Ifugao more than 2,000 years ago and were listed by UNESCO in 1995 as a World Heritage Site.", 3, 8)
			step = 7; wait = 30
		7:
			_shot("popup_timeout_long")
			step = 75; wait = 5
		75:
			game.answer_popup.close()
			game._on_leave_pressed()
			step = 8; wait = 20
		8:
			var lm = game.leave_modal; print("leave vis=", lm.visible, " rect=", lm.get_global_rect(), " center=", lm._center.get_rect(), " panel=", lm._panel.get_rect(), " scale=", lm._panel.scale)
			_shot("leave")
			return true
	return frames > 60 * 40
