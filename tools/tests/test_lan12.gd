extends SceneTree
# LAN checks for v1.2 (run in real time, one host + clients on this PC):
#   ROLE=host N=2  godot --headless --path . --script tools/tests/test_lan12.gd
#   ROLE=client    godot --headless --path . --script tools/tests/test_lan12.gd   (N-1 times)
# Prints: roles, the bot Sili (2 players), the Frozen counter after a tag,
# the moment GO happened on this device (same PC = same clock), and on the
# host whether the leaderboard got a bot entry (save file backed up/restored).
var role := OS.get_environment("ROLE")
var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 2
var frames := 0
var game
var t_go := -1
var step := 0
var t_step := 0
var lb_backup := PackedByteArray()
const LB := "user://leaderboard.cfg"

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var net = root.get_node("Network")
	root.get_node("GameState").player_name = role.capitalize() + str(OS.get_process_id() % 100)
	if role == "host":
		if FileAccess.file_exists(LB):
			lb_backup = FileAccess.get_file_as_bytes(LB)
		print("host_game: ", net.host_game())
	else:
		print("join_game: ", net.join_game("127.0.0.1"))

func _process(_d: float) -> bool:
	frames += 1
	var net = root.get_node("Network")
	var gs = root.get_node("GameState")
	if role == "host" and (current_scene == null or current_scene.name != "MazeGame") and not net.game_started:
		if net.players.size() >= n:
			print("host: %d players -> START" % net.players.size())
			net.start_game()
	if current_scene and current_scene.name == "MazeGame":
		game = current_scene
	if game == null or not is_instance_valid(game):
		return frames > 60 * 60
	var me_id: int = net.my_id()
	if t_go < 0 and gs.round_state == gs.RoundState.PLAYING:
		t_go = int(fmod(Time.get_unix_time_from_system(), 1000.0) * 1000.0)   # wall clock, shared by all copies
		var roles := []
		for p in game.player_by_id.values():
			roles.append("%s=%s%s" % [net.player_name_of(p.peer_id), p.role, " (bot)" if p.is_bot else ""])
		print("%s GO at %d ms | roles: %s | frozen label: %s | round time %s" % [role, t_go, ", ".join(roles), game.frozen_label.text, game._format_time(game.time_left)])
		t_step = frames
	if t_go < 0:
		return frames > 60 * 60
	if role == "host":
		match step:
			0:
				if frames - t_step > 120:
					# freeze one human Tubig: as if the (bot) Sili tagged them
					for t in game.tubigs:
						if t.peer_id != 1:
							game._tubig_caught.rpc(t.peer_id)
							break
					step = 1; t_step = frames
			1:
				if frames - t_step > 60:
					print("host frozen label after tag: ", game.frozen_label.text, " | bot node: ", game.has_node("BotSili_991"))
					game._host_end(false, "TEST END")
					step = 2; t_step = frames
			2:
				if frames - t_step > 60:
					var bad := false
					for r in preload("res://data/leaderboard.gd").rankings():
						if String(r["name"]).begins_with("Bot"):
							bad = true
					print("host leaderboard has a bot entry: ", bad)
					if lb_backup.is_empty():
						DirAccess.remove_absolute(ProjectSettings.globalize_path(LB))
					else:
						var f := FileAccess.open(LB, FileAccess.WRITE)
						f.store_buffer(lb_backup)
						f.close()
					print("host done (leaderboard restored)")
					step = 3; t_step = frames
			3:
				return frames - t_step > 120
	else:
		if step == 0 and frames - t_step > 200:
			print("%s frozen label after tag: %s | bot on this device: %s" % [role, game.frozen_label.text, game.player_by_id.has(991)])
			step = 1
		if step == 1 and gs.round_state == gs.RoundState.ENDED:
			print("%s saw the round end" % role)
			return true
	return frames > 60 * 60
