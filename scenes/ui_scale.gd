extends RefCounted
## UI sizing in one place (font sizes, touch targets, modal sizes, safe
## area), worked out from the real window: its size, the screen's DPI and
## the project's stretch (base 960 x 640, aspect "expand"). Sizes returned
## here are in UI units (the numbers Controls use), never physical pixels.
## Use it from any script:   const UiScale := preload("res://scenes/ui_scale.gd")
## and re-apply your layout when the viewport's size_changed fires (resize,
## rotation).

const BASE := Vector2(960, 640)


## How many physical pixels one UI unit is on this screen.
static func content_scale(vp: Viewport) -> float:
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0 or window.y <= 0:
		return 1.0
	return minf(window.x / BASE.x, window.y / BASE.y)   # "expand" keeps the shorter side


## Android-style density-independent pixels (dp) converted to UI units.
static func dp(vp: Viewport, value: float) -> float:
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0
	return value * dpi / 160.0 / content_scale(vp)


## Text size multiplier: 1.0 on desktop, bigger on phones / touch screens.
static func text_scale(vp: Viewport) -> float:
	if not GameState.is_mobile_ui():
		return clampf(vp.get_visible_rect().size.y / BASE.y, 1.0, 1.1)
	return clampf(dp(vp, 1.0) * 0.9, 1.35, 1.75)


static func font(vp: Viewport, base_size: int) -> int:
	return int(round(base_size * text_scale(vp)))


## Smallest comfortable button height / icon button size.
## Mobile: at least 48 dp (bigger on low-DPI tablets). Desktop: unchanged.
static func touch_target(vp: Viewport, desktop_size: float = 32.0) -> float:
	if not GameState.is_mobile_ui():
		return desktop_size
	return maxf(64.0, dp(vp, 48.0))


## Safe-area insets (status bar, notch, rounded corners) in UI units,
## plus a small minimum gutter on phones.
static func safe_insets(vp: Viewport) -> Dictionary:
	var gutter := 10.0 if GameState.is_mobile_ui() else 0.0
	var out := {"left": gutter, "top": gutter, "right": gutter, "bottom": gutter}
	var screen := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0 or screen.x <= 0:
		return out
	# the safe area is in screen pixels: only meaningful when the game fills
	# the whole screen (phones); a window on a PC just gets the small gutter
	if Vector2(DisplayServer.screen_get_size()) != screen:
		return out
	var s := content_scale(vp)
	out["left"] = maxf(gutter, safe.position.x / s)
	out["top"] = maxf(gutter, safe.position.y / s)
	out["right"] = maxf(gutter, (screen.x - safe.end.x) / s)
	out["bottom"] = maxf(gutter, (screen.y - safe.end.y) / s)
	# desktops report the whole monitor: ignore anything that isn't a phone
	if not GameState.is_mobile_ui():
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	return out


## The usable screen rectangle (inside the safe area), in UI units.
static func safe_rect(vp: Viewport) -> Rect2:
	var r := vp.get_visible_rect()
	var i := safe_insets(vp)
	return Rect2(r.position + Vector2(i["left"], i["top"]),
		r.size - Vector2(i["left"] + i["right"], i["top"] + i["bottom"]))


## A modal's size: a fraction of the safe area on phones, capped at a
## comfortable size on desktop.
static func modal_size(vp: Viewport, mobile_frac: Vector2, desktop_max: Vector2) -> Vector2:
	var safe := safe_rect(vp).size
	if GameState.is_mobile_ui():
		return (safe * mobile_frac).floor()
	return Vector2(minf(desktop_max.x, safe.x * 0.94), minf(desktop_max.y, safe.y * 0.94)).floor()


## True when the window is taller than wide or very narrow (one-column layouts).
static func is_narrow(vp: Viewport) -> bool:
	var size := vp.get_visible_rect().size
	return size.x < size.y * 1.1 or size.x < 700.0
