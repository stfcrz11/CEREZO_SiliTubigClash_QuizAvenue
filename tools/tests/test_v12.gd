extends SceneTree
# v1.2 checks in one Solo vs Bot game (headless, --fixed-fps 60):
#   godot --headless --fixed-fps 60 --path . --script tools/tests/test_v12.gd
# Intro + countdown, quiz window (tab, A key, feedback marks), result popup
# (host waits for it), movement-leak guard, quiz tabs, leave window, and
# questions never repeating in a session.
var game
var gs
var frames := 0
var step := 0
var wait := 0
var t_mark := 0
var fails := 0

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	root.get_node("Network").play_solo(true, 1)
	change_scene_to_file("res://scenes/maze_game.tscn")

func ok(id: String, what: String, cond: bool, detail = "") -> void:
	if not cond:
		fails += 1
	print("%s  %s  %s %s" % [id, "PASS" if cond else "FAIL", what, ("(" + str(detail) + ")") if str(detail) != "" else ""])

func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)

func _process(_d: float) -> bool:
	frames += 1
	gs = root.get_node("GameState")
	if step == 11:
		if wait > 0:
			wait -= 1
			return false
		ok("V-19", "LEAVE -> title screen", current_scene != null and current_scene.name == "TitleScreen", current_scene.name if current_scene else "none")
		print("RESULT: %d failed" % fails)
		return true
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		return false
	if wait > 0:
		wait -= 1
		return false
	var me = game.tubigs[0] if not game.tubigs.is_empty() else null
	match step:
		0:
			if me == null: return false
			var intro = game.round_intro
			ok("V-01", "intro visible with role + round line", intro.visible and intro._role_label.text == "YOU ARE THE TUBIG" and intro._round.text.begins_with("Round 1"), intro._round.text)
			ok("V-02", "round still READY during intro, clock shows full time", gs.round_state == gs.RoundState.READY and game.time_left == 180.0, game.time_left)
			t_mark = me.global_position.x
			Input.action_press("move_right")
			step = 1; wait = 60
		1:
			ok("V-03", "no movement before GO", absf(me.global_position.x - t_mark) < 0.5, me.global_position.x - t_mark)
			Input.action_release("move_right")
			step = 2
		2:
			if gs.round_state != gs.RoundState.PLAYING: return false
			ok("V-04", "GO -> PLAYING after the countdown", frames > 60 * 4, "frame %d" % frames)
			game.get_node("BotSili_991").set_physics_process(false)
			game.silis[0].force_position(game.cell_to_world(Vector2i(20, 7)))
			var sc = game.scrolls.values()[0]
			me.force_position(sc.position)
			step = 3; wait = 5
		3:
			var qp = game.quiz_panel
			ok("V-05", "scroll opens quiz with tab QUIZ", qp.visible and qp.header_label.text == "QUIZ", qp.header_label.text)
			ok("V-06", "answer labels are A-D badges", qp._badges.map(func(b): return b.text) == ["A", "B", "C", "D"])
			key(KEY_A)
			step = 4; wait = 3
		4:
			var qp = game.quiz_panel
			var marks := 0
			for m in qp._marks: if m.visible: marks += 1
			ok("V-07", "after A: feedback marks shown, popup not yet", marks >= 1 and qp.visible and not game.answer_popup.visible, "marks %d" % marks)
			ok("V-08", "movement blocked until keys are let go", gs._moves_blocked)
			step = 5; wait = 60
		5:
			ok("V-09", "popup opens after ~0.9 s feedback", game.answer_popup.visible and not game.quiz_panel.visible)
			step = 6; wait = 120
		6:
			ok("V-10", "host waits while the popup is open (answerer still safe)", me.answering and game.answer_popup.visible)
			key(KEY_SPACE)
			step = 7; wait = 10
		7:
			ok("V-11", "key closes popup and play resumes", not game.answer_popup.visible and not me.answering, "popup %s answering %s state %s host qs %s popup_q %s" % [game.answer_popup.visible, me.answering, gs.round_state, game._questions, game.popup_question])
			# quiz tabs for every kind
			var tabs := []
			for k in ["thaw", "rescue", "turbo", "gate"]:
				tabs.append(game._question_tab(k, {"step": 1}))
			var shield_id := -1
			for st in game.stations:
				if st["kind"] == "stall": shield_id = st["id"]
			tabs.append(game._question_tab("shield", {"station": shield_id}))
			ok("V-12", "tabs: HULING HIRIT 1/2, BUHOS-TUBIG, BUGTONG, KALAMANSI GATE, cooler flavor", tabs[0] == "HULING HIRIT 1/2" and tabs[1] == "BUHOS-TUBIG" and tabs[2] == "BUGTONG" and tabs[3] == "KALAMANSI GATE" and tabs[4] in ["HALO-HALO", "MAIS CON YELO", "SAGO'T GULAMAN", "BUKO PANDAN"], tabs)
			# leave window
			game._on_leave_pressed()
			step = 8; wait = 3
		8:
			ok("V-13", "leave window open, solo round paused, touch blocked", game.leave_modal.is_open() and gs.round_state == gs.RoundState.PAUSED and game.get_node("HUD/TouchControls").is_blocked.call())
			ok("V-14", "solo message", game.leave_modal._message.text == "Your progress in this run will be lost.", game.leave_modal._message.text)
			var e := InputEventAction.new(); e.action = "ui_cancel"; e.pressed = true
			Input.parse_input_event(e)
			step = 9; wait = 3
		9:
			ok("V-15", "Esc = STAY: window closed, round resumed", not game.leave_modal.is_open() and gs.round_state == gs.RoundState.PLAYING)
			# questions never repeat in a session
			gs.reset_question_decks()
			var seen := {}
			var dup := false
			for i in 49:
				var q: int = gs.next_question_index("normal", 49)
				if seen.has(q): dup = true
				seen[q] = true
			ok("V-16", "49 general questions, no repeats", not dup and seen.size() == 49)
			var last: int = gs._last_question["normal"]
			var next: int = gs.next_question_index("normal", 49)
			ok("V-17", "pool used up -> new cycle, not the last one first", next != last, "%d after %d" % [next, last])
			gs.reset_question_decks()
			var tiny := []
			for i in 9: tiny.append(gs.next_question_index("tiny", 3))
			var ok_cycles: bool = tiny.slice(0, 3).duplicate() != [] and tiny[2] != tiny[3] and tiny[5] != tiny[6]
			var sorted_a: Array = tiny.slice(0, 3); sorted_a.sort()
			var sorted_b: Array = tiny.slice(3, 6); sorted_b.sort()
			ok("V-18", "tiny pool of 3 reshuffles cleanly", ok_cycles and sorted_a == [0, 1, 2] and sorted_b == [0, 1, 2], tiny)
			game._on_leave_pressed()
			step = 10; wait = 3
		10:
			game.leave_modal._danger_button.pressed.emit()
			step = 11; wait = 20
		11:
			ok("V-19", "LEAVE -> title screen", current_scene != null and current_scene.name == "TitleScreen", current_scene.name if current_scene else "none")
			print("RESULT: %d failed" % fails)
			return true
	return frames > 60 * 120
