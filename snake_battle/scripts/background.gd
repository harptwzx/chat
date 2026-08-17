extends Node2D

var world_half := 1000.0

func set_world_half(v: float) -> void:
	if absf(world_half - v) > 0.5:
		world_half = v
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var size := Vector2(world_half * 2.0, world_half * 2.0)
	var rect := Rect2(Vector2(-world_half, -world_half), size)
	draw_rect(rect, Color(0.08, 0.10, 0.12))
	var grid := Color(0.18, 0.22, 0.26, 0.5)
	var step := 50.0
	var x := -world_half
	while x <= world_half + 0.5:
		draw_line(Vector2(x, -world_half), Vector2(x, world_half), grid, 1.0)
		x += step
	var y := -world_half
	while y <= world_half + 0.5:
		draw_line(Vector2(-world_half, y), Vector2(world_half, y), grid, 1.0)
		y += step
	draw_rect(rect, Color(0.85, 0.90, 0.95, 0.9), false, 4.0)