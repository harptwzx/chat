extends RefCounted

const SEG_SPACING := 6.0
const PATH_STEP := 4.0
const BASE_SPEED := 160.0
const BOOST_MULT := 1.6
const BOOST_DRAIN := 4.0
const MAX_TURN := 7.0
const START_LENGTH := 60.0
const PATH_BACK := 16

var peer_id := 0
var display_name := ""
var color := Color.WHITE
var alive := true
var has_input := false
var instant_turn := false
var head_pos := Vector2.ZERO
var angle := 0.0
var target_angle := 0.0
var boosting := false
var speed := 0.0
var length := START_LENGTH
var respawn_timer := 0.0
var path: Array[Vector2] = []
var body_points := PackedVector2Array()

func spawn(pos: Vector2) -> void:
	alive = true
	has_input = false
	instant_turn = false
	boosting = false
	length = START_LENGTH
	respawn_timer = 0.0
	head_pos = pos
	angle = randf_range(0.0, TAU)
	target_angle = angle
	var back := Vector2.from_angle(angle + PI)
	path = []
	for k in range(PATH_BACK, -1, -1):
		path.append(head_pos + back * PATH_STEP * k)
	_compute_body_points()

func grow(amount: float) -> void:
	length += amount

func tick(delta: float) -> void:
	if not alive:
		return
	if not has_input:
		_compute_body_points()
		return
	if instant_turn:
		angle = target_angle
	else:
		var da := wrapf(target_angle - angle, -PI, PI)
		var max_step := MAX_TURN * delta
		if absf(da) > max_step:
			angle += signf(da) * max_step
		else:
			angle = target_angle
	var speed_mult := minf(1.0 + length * 0.0008, 1.6)
	speed = BASE_SPEED * speed_mult
	if boosting:
		speed *= BOOST_MULT
		length = maxf(20.0, length - BOOST_DRAIN * delta)
	head_pos += Vector2.from_angle(angle) * speed * delta
	if path.is_empty() or head_pos.distance_to(path[path.size() - 1]) >= PATH_STEP:
		path.append(head_pos)
		_prune_path()
	_compute_body_points()

func _prune_path() -> void:
	var target := length + 40.0
	var acc := 0.0
	var i := path.size() - 1
	while i > 0:
		acc += path[i].distance_to(path[i - 1])
		if acc >= target:
			path = path.slice(i)
			return
		i -= 1

func _compute_body_points() -> void:
	var pts := PackedVector2Array()
	pts.append(head_pos)
	var remaining := length
	var anchor := head_pos
	var i := path.size() - 1
	while remaining > 0.0 and i >= 0:
		var p: Vector2 = path[i]
		var seg := anchor.distance_to(p)
		if seg <= 0.001:
			i -= 1
			continue
		if seg > remaining:
			pts.append(anchor + (p - anchor).normalized() * remaining)
			remaining = 0.0
			break
		var n := maxi(1, int(seg / SEG_SPACING))
		for k in range(1, n + 1):
			pts.append(anchor.lerp(p, float(k) / float(n)))
		remaining -= seg
		anchor = p
		i -= 1
	body_points = pts

func to_dict() -> Dictionary:
	return {
		"id": peer_id,
		"name": display_name,
		"color": color,
		"alive": alive,
		"head": head_pos,
		"angle": angle,
		"boost": boosting,
		"length": length,
		"respawn": respawn_timer,
		"points": body_points,
	}