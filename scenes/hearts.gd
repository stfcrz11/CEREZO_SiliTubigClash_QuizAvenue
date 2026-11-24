extends Control
## A row of pixel hearts for the in-game HUD (one row per Tubig, top left).
## total = how many hearts, full = how many are still red.
## frozen = the player is frozen right now: the red hearts turn icy blue.
## Drawn in code from a 7 x 6 bitmap, so there's no picture to replace.

const SHAPE := [
	".##.##.",
	"#######",
	"#######",
	".#####.",
	"..###..",
	"...#...",
]
const RED := Color(0.93, 0.22, 0.27)
const ICE := Color(0.55, 0.85, 1.0)
const EMPTY := Color(0.2, 0.22, 0.28, 0.85)
const OUTLINE := Color(0.05, 0.04, 0.08)

var total: int = 3:
	set(v):
		if v != total:
			total = v
			_resize()
var full: int = 3:
	set(v):
		if v != full:
			full = v
			queue_redraw()
var frozen: bool = false:
	set(v):
		if v != frozen:
			frozen = v
			queue_redraw()
var px: float = 3.0:      # size of one heart pixel
	set(v):
		if v != px:
			px = v
			_resize()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _resize() -> void:
	# 7 pixels wide + 1 pixel outline each side, 2 pixels between hearts
	custom_minimum_size = Vector2(total * 11.0 * px - 2.0 * px, 8.0 * px)
	queue_redraw()


func _draw() -> void:
	var y0 := (size.y - 8.0 * px) / 2.0
	for i in total:
		var origin := Vector2(i * 11.0 * px, y0)
		var fill := EMPTY
		if i < full:
			fill = ICE if frozen else RED
		# outline: the shape drawn 1 pixel bigger in every direction
		for row in SHAPE.size():
			for col in SHAPE[row].length():
				if SHAPE[row][col] == "#":
					draw_rect(Rect2(origin + Vector2(col * px, row * px), Vector2(px * 3.0, px * 3.0)), OUTLINE)
		for row in SHAPE.size():
			for col in SHAPE[row].length():
				if SHAPE[row][col] == "#":
					draw_rect(Rect2(origin + Vector2((col + 1) * px, (row + 1) * px), Vector2(px, px)), fill)
		# a small shine on red / blue hearts
		if i < full:
			draw_rect(Rect2(origin + Vector2(2 * px, 2 * px), Vector2(px, px)), Color(1, 1, 1, 0.55))
