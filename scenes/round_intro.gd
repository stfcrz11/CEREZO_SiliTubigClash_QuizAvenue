extends Control
## Pre-round intro: a role reveal ("YOU ARE THE TUBIG" / "YOU ARE THE SILI",
## the character, the goal, who plays what, the solo round) then a big
## 3 -> 2 -> 1 -> GO! countdown. maze_game.gd drives it:
##   intro.open(info)    show the reveal and start the local countdown
##   intro.go()          the host's GO arrived: show GO! and fade away
## The countdown numbers run on this device's own timer from the moment the
## reveal arrives (no shared clock needed); it waits on "1" until GO comes,
## so everyone starts on the host's GO. While the intro shows the round
## state is READY, so nobody moves, tags or opens questions.
## Built in code (scenes/pixel_ui.gd + scenes/ui_scale.gd).

const UiScale := preload("res://scenes/ui_scale.gd")
const PixelUI := preload("res://scenes/pixel_ui.gd")
const TUBIG_SHEET := preload("res://assets/characters/tubig_sheet.png")
const SILI_SHEET := preload("res://assets/characters/sili_sheet.png")

const REVEAL_TIME := 2.2     # seconds of role reveal before the numbers
const STEP_TIME := 0.8       # seconds per number (3, 2, 1)
## Host waits this long after sending the intro before GO.
const TOTAL_TIME := REVEAL_TIME + STEP_TIME * 3

var _role_label: Label
var _sprite: TextureRect
var _goal: Label
var _roster: Label
var _round: Label
var _count: Label
var _center: CenterContainer
var _box: VBoxContainer
var _t: float = 0.0
var _running: bool = false
var _shown_step: int = -1


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # the leave button still works
	var dim := PixelUI.dim(0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_box)
	_round = PixelUI.pixel_label("", 32, PixelUI.GOLD_TEXT)
	_box.add_child(_round)
	_role_label = PixelUI.pixel_label("YOU ARE THE TUBIG", 64, PixelUI.TUBIG_BLUE)
	_box.add_child(_role_label)
	_sprite = TextureRect.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_sprite)
	_goal = _text(Color(0.96, 0.96, 1.0))
	_box.add_child(_goal)
	_roster = _text(Color(0.75, 0.8, 0.9))
	_box.add_child(_roster)
	_count = PixelUI.pixel_label("", 128, Color.WHITE)
	_box.add_child(_count)
	get_viewport().size_changed.connect(_layout)


func _text(color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## info: {role: "tubig"/"sili", goal: String, roster: String, round: String}
func open(info: Dictionary) -> void:
	var tubig: bool = info.get("role", "tubig") == "tubig"
	_role_label.text = "YOU ARE THE TUBIG" if tubig else "YOU ARE THE SILI"
	_role_label.add_theme_color_override("font_color", PixelUI.TUBIG_BLUE if tubig else PixelUI.SILI_RED)
	var atlas := AtlasTexture.new()
	atlas.atlas = TUBIG_SHEET if tubig else SILI_SHEET
	atlas.region = Rect2(0, 0, 32, 32)
	_sprite.texture = atlas
	_goal.text = info.get("goal", "")
	_roster.text = info.get("roster", "")
	_round.text = info.get("round", "")
	_round.visible = not _round.text.is_empty()
	_count.text = ""
	_t = 0.0
	_shown_step = -1
	_running = true
	modulate.a = 1.0
	visible = true
	_layout()
	_role_label.pivot_offset = _role_label.size / 2.0
	_role_label.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(_role_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_open() -> bool:
	return visible


func _layout() -> void:
	var vp := get_viewport()
	var safe := UiScale.safe_rect(vp)
	var mobile := GameState.is_mobile_ui()
	_role_label.add_theme_font_size_override("font_size",
		PixelUI.pixel_size_fit(safe.size.y * (0.11 if mobile else 0.09), _role_label.text, safe.size.x * 0.94))
	_round.add_theme_font_size_override("font_size", PixelUI.pixel_size_fit(UiScale.font(vp, 22), _round.text, safe.size.x * 0.94))
	_sprite.custom_minimum_size = Vector2.ONE * safe.size.y * 0.2
	_goal.add_theme_font_size_override("font_size", UiScale.font(vp, 22))
	_roster.add_theme_font_size_override("font_size", UiScale.font(vp, 16))
	_count.add_theme_font_size_override("font_size", PixelUI.pixel_size(safe.size.y * 0.16))
	_count.custom_minimum_size.y = safe.size.y * 0.18
	_goal.custom_minimum_size.x = safe.size.x * 0.8
	_roster.custom_minimum_size.x = safe.size.x * 0.8
	PixelUI.fit_to_safe(_center, vp)


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	if _t < REVEAL_TIME:
		return
	var step := mini(2, int((_t - REVEAL_TIME) / STEP_TIME))   # 0 = "3" ... 2 = "1" (waits on 1)
	if step != _shown_step:
		_shown_step = step
		_show_count(str(3 - step), Color.WHITE)
		Sound.play("click")


func _show_count(text: String, color: Color) -> void:
	_count.text = text
	_count.add_theme_color_override("font_color", color)
	_count.pivot_offset = _count.size / 2.0
	_count.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(_count, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The host's GO: show GO! and fade out.
func go() -> void:
	if not visible:
		return
	_running = false
	_show_count("GO!", PixelUI.GREEN)
	var fade := create_tween()
	fade.tween_interval(0.55)
	fade.tween_property(self, "modulate:a", 0.0, 0.35)
	fade.tween_callback(func(): visible = false)


func close() -> void:
	_running = false
	visible = false
