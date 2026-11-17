extends SceneTree
# Title-screen checks (run twice: SILITUBIG_MOBILE_UI=0 and =1):
#   godot --path . --resolution 1280x720 --script tools/tests/test_ui12.gd
# Finger-drag scrolling of Credits / How to Play, the joystick switch only on
# touch devices, and platform-only control texts. OUT=<folder> saves shots.
var t
var frames := 0
var step := 0
var mobile := OS.get_environment("SILITUBIG_MOBILE_UI") == "1"
var out := OS.get_environment("OUT")
var tag := ("phone" if mobile else "desk") + OS.get_environment("TAG")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	change_scene_to_file("res://scenes/title_screen.tscn")

func ok(id: String, what: String, cond: bool, detail = "") -> void:
	print("%s  %s  [%s] %s %s" % [id, "PASS" if cond else "FAIL", "phone" if mobile else "desktop", what, ("(" + str(detail) + ")") if str(detail) != "" else ""])

func _shot(n: String) -> void:
	if out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/title_%s_%s.png" % [out, tag, n])

## Phone: finger drags. Desktop: mouse wheel (desktops don't send touch drags).
func drag(scroll: ScrollContainer, times: int) -> void:
	var r := scroll.get_global_rect()
	var p := r.position + r.size * Vector2(0.4, 0.7)
	if not mobile:
		for i in times:
			for pressed in [true, false]:
				var w := InputEventMouseButton.new()
				w.button_index = MOUSE_BUTTON_WHEEL_DOWN
				w.pressed = pressed
				w.position = p
				w.global_position = p
				root.push_input(w)
		return
	for i in times:
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = p
		e.relative = Vector2(0, -60)
		e.velocity = Vector2(0, -600)
		root.push_input(e)

func _process(_d: float) -> bool:
	frames += 1
	if t == null:
		t = current_scene
		return false
	match step:
		0:
			if frames < 20: return false
			t._show_credits(true)
			step = 1
		1:
			if frames < 30: return false
			var scroll: ScrollContainer = t.get_node("CreditsPanel/Margin/VBox/Scroll")
			_shot("credits_top")
			drag(scroll, 80)
			step = 2
		2:
			if frames < 40: return false
			var scroll: ScrollContainer = t.get_node("CreditsPanel/Margin/VBox/Scroll")
			var bar := scroll.get_v_scroll_bar()
			ok("U-01", "finger drag (phone) / wheel (desktop) scrolls Credits to the bottom", scroll.scroll_vertical > 0 and scroll.scroll_vertical >= int(bar.max_value - bar.page) - 2, "%d of %d" % [scroll.scroll_vertical, int(bar.max_value - bar.page)])
			ok("U-02", "scrollbar is wide enough to grab", bar.custom_minimum_size.x >= (26.0 if mobile else 14.0), bar.custom_minimum_size.x)
			_shot("credits_bottom")
			t._show_credits(false)
			t._show_how_to(true)
			step = 3
		3:
			if frames < 50: return false
			var rules: RichTextLabel = t.get_node("HowToPanel/Margin/VBox/Scroll/Rules")
			var txt := rules.get_parsed_text()
			if mobile:
				ok("U-03", "How to Play: touch words only", txt.contains("Drag on the right half") and not txt.contains("W A S D") and not txt.contains("Esc"))
			else:
				ok("U-03", "How to Play: keyboard words only", txt.contains("W A S D") and txt.contains(" A ") and not txt.contains("Drag on the right half") and not txt.contains("tap USE"))
			ok("U-04", "How to Play: no 1-4 answer keys as the main keys, no tap-twice", not txt.contains("tap twice") and not txt.contains("Answer by click, tap or"))
			var scroll: ScrollContainer = t.get_node("HowToPanel/Margin/VBox/Scroll")
			drag(scroll, 200)
			_shot("howto")
			step = 4
		4:
			if frames < 60: return false
			var scroll: ScrollContainer = t.get_node("HowToPanel/Margin/VBox/Scroll")
			var bar := scroll.get_v_scroll_bar()
			ok("U-05", "finger drag (phone) / wheel (desktop) scrolls How to Play to the bottom", scroll.scroll_vertical >= int(bar.max_value - bar.page) - 2, "%d of %d" % [scroll.scroll_vertical, int(bar.max_value - bar.page)])
			t._show_how_to(false)
			t.get_node("SettingsPanel").open()
			step = 5
		5:
			if frames < 70: return false
			var vbox = t.get_node("SettingsPanel").music_on.get_parent().get_parent()
			ok("U-06", "joystick switch only on touch devices", vbox.get_node("TouchRow").visible == mobile)
			var controls: String = vbox.get_node("Controls").get_parsed_text()
			ok("U-07", "Settings controls text matches the platform", controls.contains("Drag") == mobile and controls.contains("W A S D") != mobile)
			_shot("settings")
			step = 6
		6:
			if frames < 80: return false
			return true
	return frames > 600
