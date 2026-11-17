extends RefCounted
## Makes a ScrollContainer scroll with a finger on phones (and keeps the mouse
## wheel / scrollbar working on desktop). Used by How to Play, Credits and
## Leaderboard:   TouchScroll.setup($Panel/.../Scroll)
##
## Why finger scrolling failed before: RichTextLabel and PanelContainer
## children catch mouse/touch input by default (mouse_filter STOP), so the
## drag never reached the ScrollContainer. Here every child passes input on,
## the scrollbar gets a wide, visible grabber, and touch drags scroll the
## container even where Godot doesn't report a touch screen.

const UiScale := preload("res://scenes/ui_scale.gd")


static func setup(scroll: ScrollContainer) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 6
	_pass_input(scroll)
	style_scrollbar(scroll)
	if not scroll.child_entered_tree.is_connected(_on_child_added.bind(scroll)):
		scroll.child_entered_tree.connect(_on_child_added.bind(scroll))
	scroll.gui_input.connect(func(event: InputEvent):
		# Godot scrolls by itself on real touch screens (through mouse emulation);
		# raw touch drags are handled here for devices it doesn't treat as touch.
		if event is InputEventScreenDrag and not DisplayServer.is_touchscreen_available():
			scroll.scroll_vertical = int(scroll.scroll_vertical - event.relative.y)
			scroll.accept_event())


## Wide grabber that is easy to see and grab (wider on phones).
static func style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	var width := 26.0 if GameState.is_mobile_ui() else 14.0
	bar.custom_minimum_size.x = width
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.06, 0.07, 0.1, 0.8)
	track.set_corner_radius_all(0)
	track.content_margin_left = width
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.93, 0.7, 0.2)
	grab.border_color = Color(0.13, 0.1, 0.08)
	grab.set_border_width_all(2)
	grab.set_corner_radius_all(0)
	grab.anti_aliasing = false
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = Color(1.0, 0.82, 0.35)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hi)


static func _on_child_added(_node: Node, scroll: ScrollContainer) -> void:
	_pass_input(scroll)


## Every Control inside the scroll lets touch/mouse through to it (buttons
## keep working: they only take taps, the scroll still gets the drag).
static func _pass_input(node: Node) -> void:
	for child in node.get_children():
		if child is ScrollBar:
			continue
		if child is Control and not (child is BaseButton or child is LineEdit):
			if child.mouse_filter == Control.MOUSE_FILTER_STOP:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
		_pass_input(child)
