extends Node2D

const SNAKE_RADIUS := 8.0

var snake_color := Color.WHITE
var head_pos := Vector2.ZERO
var head_angle := 0.0

var line: Line2D
var head: Node2D

var _target_head := Vector2.ZERO
var _target_angle := 0.0
var _target_points := PackedVector2Array()
var _initialized := false
var _was_visible := true

func _ready() -> void:
	line = Line2D.new()
	line.name = "Body"
	line.width = SNAKE_RADIUS * 2.0
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.default_color = snake_color
	line.antialiased = false
	add_child(line)
	head = Node2D.new()
	head.name = "Head"
	add_child(head)
	head.draw.connect(_draw_head)

func update_view(hp: Vector2, points: PackedVector2Array, ang: float) -> void:
	head_pos = hp
	head_angle = ang
	_target_head = hp
	_target_angle = ang
	_target_points = points
	if not _initialized:
		_initialized = true
		head.position = hp
		line.points = points
		head.queue_redraw()

func snap_to(hp: Vector2, points: PackedVector2Array, ang: float) -> void:
	head_pos = hp
	head_angle = ang
	_target_head = hp
	_target_angle = ang
	_target_points = points
	_initialized = true
	head.position = hp
	line.points = points
	head.queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		_was_visible = false
		return
	if not _was_visible:
		_was_visible = true
		head.position = _target_head
		head_angle = _target_angle
		line.points = _target_points
		head.queue_redraw()
		return
	var k := 1.0 - exp(-18.0 * delta)
	if _target_points.size() >= 2 and line.points.size() == _target_points.size():
		var pts := line.points
		for i in range(pts.size()):
			pts[i] = pts[i].lerp(_target_points[i], k)
		line.points = pts
	else:
		line.points = _target_points
	head.position = head.position.lerp(_target_head, k)
	head_angle = lerp_angle(head_angle, _target_angle, k)
	head.queue_redraw()

func _draw_head() -> void:
	var dir := Vector2.from_angle(head_angle)
	head.draw_circle(Vector2.ZERO, SNAKE_RADIUS + 1.5, snake_color.darkened(0.35))
	head.draw_circle(Vector2.ZERO, SNAKE_RADIUS, snake_color)
	var side := Vector2(-dir.y, dir.x)
	var eye := dir * SNAKE_RADIUS * 0.5
	head.draw_circle(eye + side * SNAKE_RADIUS * 0.22, SNAKE_RADIUS * 0.28, Color.WHITE)
	head.draw_circle(eye - side * SNAKE_RADIUS * 0.22, SNAKE_RADIUS * 0.28, Color.WHITE)
	head.draw_circle(eye + side * SNAKE_RADIUS * 0.22 + dir * SNAKE_RADIUS * 0.12, SNAKE_RADIUS * 0.12, Color.BLACK)
	head.draw_circle(eye - side * SNAKE_RADIUS * 0.22 + dir * SNAKE_RADIUS * 0.12, SNAKE_RADIUS * 0.12, Color.BLACK)