extends RefCounted
## SOLO VS BOT progress saved on this device (user://solo_save.cfg), one
## section per map id. There is one map for now: "classic_maze".
##
##   [classic_maze]
##   schema=1  round=3  difficulty="Hard"  saved_at=1763700000
##
## Rules (see maze_game.gd and title_screen.gd):
##   a round starts        -> that round is saved
##   round N won (N < 4)   -> N + 1 is saved at once (even if you quit then)
##   round lost / left     -> the same round stays saved (retry)
##   round 4 won           -> the save is cleared
##   NEW GAME              -> the save is replaced with round 1
## RESUME starts a fresh round at the saved number (no mid-round snapshot).
## A missing, damaged or hand-edited file counts as "no save" (never crashes).

const PATH := "user://solo_save.cfg"
const SCHEMA := 1
const DEFAULT_MAP := "classic_maze"
const ROUNDS := 4
const DIFFICULTY := ["Easy", "Medium", "Hard", "Labuyo"]


## The saved game for a map, or {} when there is none (or it is unreadable).
## {"round": int 1-4, "difficulty": String, "saved_at": int (unix time)}
static func load_save(map_id: String = DEFAULT_MAP) -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(PATH) or cfg.load(PATH) != OK:
		return {}
	if not cfg.has_section(map_id):
		return {}
	var schema = cfg.get_value(map_id, "schema", 0)
	var round = cfg.get_value(map_id, "round", 0)
	var saved_at = cfg.get_value(map_id, "saved_at", 0)
	if not (schema is int) or schema != SCHEMA:
		return {}
	if not (round is int) or round < 1 or round > ROUNDS:
		return {}
	return {
		"round": round,
		"difficulty": difficulty_label(round),
		"saved_at": saved_at if saved_at is int else 0,
	}


## Save `round` (1-4) for a map, keeping other maps' saves.
static func save_round(round: int, map_id: String = DEFAULT_MAP) -> void:
	round = clampi(round, 1, ROUNDS)
	var cfg := _open_for_write()
	cfg.set_value(map_id, "schema", SCHEMA)
	cfg.set_value(map_id, "round", round)
	cfg.set_value(map_id, "difficulty", difficulty_label(round))
	cfg.set_value(map_id, "saved_at", int(Time.get_unix_time_from_system()))
	cfg.save(PATH)


## Forget a map's save (all 4 rounds cleared).
static func clear(map_id: String = DEFAULT_MAP) -> void:
	var cfg := _open_for_write()
	if cfg.has_section(map_id):
		cfg.erase_section(map_id)
	cfg.save(PATH)


static func difficulty_label(round: int) -> String:
	return DIFFICULTY[clampi(round, 1, ROUNDS) - 1]


## "Round 3 - Hard"
static func describe(save: Dictionary) -> String:
	return "Round %d - %s" % [save.get("round", 1), save.get("difficulty", "Easy")]


## The file to write into: the existing one, or a fresh one when it is
## missing or damaged (a damaged file is simply replaced).
static func _open_for_write() -> ConfigFile:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(PATH) and cfg.load(PATH) != OK:
		cfg = ConfigFile.new()
	return cfg
