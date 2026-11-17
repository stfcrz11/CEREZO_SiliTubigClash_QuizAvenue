extends RefCounted
## The shared pixel-art modal look (dark navy panel with the cream/grey
## rooftop frame, yellow pixel titles, chunky buttons). Every new window
## (quiz, result popup, leave confirmation, round intro) is built from these
## pieces so they all match. Use:  const PixelUI := preload("res://scenes/pixel_ui.gd")

const ButtonStyle := preload("res://scenes/ui_button_style.gd")
const PANEL_TEX := preload("res://assets/ui/panel.png")
const PIXEL_FONT := preload("res://assets/fonts/pixel5x7.fnt")

const NAVY := Color(0.14, 0.15, 0.2)
const NAVY_DARK := Color(0.09, 0.1, 0.14)
const CREAM := Color(0.83, 0.8, 0.8)
const GOLD := Color(0.93, 0.7, 0.2)
const GOLD_TEXT := Color(1.0, 0.85, 0.35)
const OUTLINE := Color(0.13, 0.1, 0.08)
const GREEN := Color(0.35, 0.85, 0.42)
const RED := Color(0.92, 0.3, 0.25)
const ORANGE := Color(1.0, 0.65, 0.2)
const TUBIG_BLUE := Color(0.33, 0.68, 1.0)
const SILI_RED := Color(1.0, 0.36, 0.3)


## The window frame (same 9-slice picture as the title screen windows).
static func panel_style(margin: float = 20.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEX
	box.texture_margin_left = 20
	box.texture_margin_top = 20
	box.texture_margin_right = 20
	box.texture_margin_bottom = 20
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box


## A flat pixel box (no rounded corners) with a dark outline.
static func box_style(fill: Color, border: Color = OUTLINE, width: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## A label in the pixel font (outlined, so it reads over anything).
static func pixel_label(text: String, size: int, color: Color = GOLD_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(4, size / 6))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", maxi(2, size / 12))
	label.add_theme_constant_override("shadow_offset_y", maxi(2, size / 12))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A small yellow plaque with pixel text (window title tabs).
static func plaque(text: String, size: int) -> PanelContainer:
	var p := PanelContainer.new()
	var box := box_style(GOLD, OUTLINE, 4)
	box.border_width_bottom = 8      # thick bottom edge like the buttons
	box.content_margin_left = size * 0.8
	box.content_margin_right = size * 0.8
	box.content_margin_top = size * 0.25
	box.content_margin_bottom = size * 0.25
	p.add_theme_stylebox_override("panel", box)
	var label := pixel_label(text, size, Color(0.18, 0.12, 0.08))
	label.remove_theme_color_override("font_outline_color")
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(1, 0.95, 0.7, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.name = "Text"
	p.add_child(label)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A dark see-through layer that covers the screen and swallows every tap
## behind a window (including the joystick and RUN button).
static func dim(alpha: float = 0.62) -> ColorRect:
	var d := ColorRect.new()
	d.name = "Dim"
	d.color = Color(0, 0, 0, alpha)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return d


## A big chunky button. kind: "primary" (gold), "danger" (red),
## "secondary" (wood), "plain" (grey).
static func button(text: String, kind: String, min_height: float, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	match kind:
		"danger":
			ButtonStyle.style_primary(b, Color(0.84, 0.23, 0.18), Color(1, 0.98, 0.95))
		"secondary":
			ButtonStyle.style_primary(b, Color(0.59, 0.38, 0.21), Color(1, 0.98, 0.95))
		"plain":
			ButtonStyle.style_primary(b, Color(0.42, 0.44, 0.5), Color(1, 1, 1))
		_:
			ButtonStyle.style_primary(b, GOLD, Color(0.16, 0.11, 0.09))
	b.add_theme_font_override("font", PIXEL_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.custom_minimum_size = Vector2(0, min_height)
	return b


## Pixel font sizes look sharpest at multiples of 16.
static func pixel_size(target: float) -> int:
	return maxi(16, int(round(target / 16.0)) * 16)


## Stretch a control over the safe area with anchors (not a fixed size), so
## Godot re-fits it whenever its content's size settles (wrapped text).
static func fit_to_safe(control: Control, vp: Viewport) -> void:
	const UiScaleRef := preload("res://scenes/ui_scale.gd")
	var i: Dictionary = UiScaleRef.safe_insets(vp)
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = i["left"]
	control.offset_top = i["top"]
	control.offset_right = -i["right"]
	control.offset_bottom = -i["bottom"]


## The biggest sharp pixel-font size (multiple of 16) at most `target` that
## still fits `text` in `max_width` (each letter is 0.75 of the size wide).
static func pixel_size_fit(target: float, text: String, max_width: float) -> int:
	var fit := max_width / maxf(1.0, text.length() * 0.75)
	return maxi(16, int(floor(minf(target, fit) / 16.0)) * 16)
