extends Node2D

const FOOD_RADIUS := 5.0
const FOOD_VALUE := 3.0
const SNAKE_RADIUS := 8.0
const RESPAWN_TIME := 3.0
const BROADCAST_INTERVAL := 1.0 / 60.0
const INPUT_INTERVAL := 1.0 / 60.0
const COLORS: Array[Color] = [
	Color(0.95, 0.35, 0.35),
	Color(0.35, 0.65, 0.95),
	Color(0.45, 0.85, 0.45),
	Color(0.95, 0.80, 0.30),
	Color(0.80, 0.45, 0.90),
	Color(0.25, 0.85, 0.85),
	Color(0.95, 0.55, 0.25),
	Color(0.85, 0.85, 0.85),
]

const SnakeSim = preload("res://scripts/snake.gd")
const SnakeViewSim = preload("res://scripts/snake_view.gd")

var world_half := 1000.0
var food_count := 400
var food_max := 800
var snakes: Dictionary = {}
var foods := PackedVector2Array()
var latest_snapshot := {}
var snakes_view: Dictionary = {}
var lb_labels: Array[Label] = []
var camera_pos := Vector2.ZERO
var my_length := 0.0
var last_angle := 0.0
var input_timer := 0.0
var broadcast_timer := 0.0
var host_left := false
var host_ip_base := ""
var _new_snapshot := false
var _mouse_steer_until := 0
var _joystick_was_active := false

@onready var background = $Background
@onready var food_layer = $FoodLayer
@onready var snake_layer: Node2D = $SnakeLayer
@onready var camera: Camera2D = $Camera2D
@onready var hud_length: Label = $HUD/LengthLabel
@onready var hud_lb: VBoxContainer = $HUD/Leaderboard
@onready var death_overlay: Control = $HUD/DeathOverlay
@onready var death_label: Label = $HUD/DeathOverlay/DeathLabel
@onready var leave_button: Button = $HUD/LeaveButton
@onready var host_ip_label: Label = $HUD/HostIpLabel
@onready var joystick = $HUD/Joystick
@onready var boost_button = $HUD/BoostButton

func _ready() -> void:
	Network.player_ready_received.connect(_on_player_ready_received)
	Network.peer_disconnected.connect(_on_peer_disconnected)
	leave_button.pressed.connect(_on_leave_pressed)
	camera.make_current()
	if multiplayer.is_server():
		world_half = Network.world_half
		_show_host_ip()
		_server_init()
	else:
		Network._player_ready.rpc_id(1, Network.player_name)

func _show_host_ip() -> void:
	host_ip_label.visible = true
	var ips := Network.get_local_ips()
	var ip_str := " / ".join(ips) if not ips.is_empty() else "未检测到局域网IP"
	host_ip_base = "主机IP: %s   端口: %d" % [ip_str, Network.last_port]
	host_ip_label.text = host_ip_base

func _refresh_lag_status() -> void:
	if Network.is_laggy():
		host_ip_label.text = host_ip_base + "\n帧率偏低，已暂停接受新玩家"
	else:
		host_ip_label.text = host_ip_base

func _server_init() -> void:
	food_count = _food_count_for(world_half)
	food_max = food_count + 300
	for i in range(food_count):
		_spawn_food()
	for pid in Network.pending_ready:
		_add_snake(pid, Network.pending_ready[pid])
	Network.pending_ready.clear()
	_add_snake(1, Network.player_name)

func _food_count_for(wh: float) -> int:
	var area := (wh * 2.0) * (wh * 2.0)
	return clampi(int(area / 10000.0), 100, 1200)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		_send_client_input(delta)

func _server_tick(delta: float) -> void:
	if snakes.has(1):
		var host: SnakeSim = snakes[1]
		host.has_input = true
		host.target_angle = _get_target_angle()
		host.boosting = _is_boosting()
		host.instant_turn = joystick.is_active
	var died: Array[SnakeSim] = []
	for id in snakes:
		var s: SnakeSim = snakes[id]
		if not s.alive:
			s.respawn_timer -= delta
			if s.respawn_timer <= 0.0:
				s.spawn(_find_spawn())
			continue
		s.tick(delta)
		_check_food_eat(s)
		if _check_death(s):
			died.append(s)
	for s in died:
		_kill_snake(s)
	broadcast_timer -= delta
	if broadcast_timer <= 0.0:
		broadcast_timer += BROADCAST_INTERVAL
		_broadcast_state()

func _send_client_input(delta: float) -> void:
	input_timer -= delta
	if input_timer > 0.0:
		return
	input_timer = INPUT_INTERVAL
	if host_left:
		return
	var angle := _get_target_angle()
	var boost := _is_boosting()
	var snap: bool = joystick.is_active
	_send_input.rpc_id(1, angle, boost, snap)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_input(angle: float, boost: bool, snap: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if snakes.has(sender):
		var s: SnakeSim = snakes[sender]
		s.has_input = true
		s.target_angle = angle
		s.boosting = boost
		s.instant_turn = snap

func _get_target_angle() -> float:
	if joystick.is_active:
		_joystick_was_active = true
		_mouse_steer_until = 0
		if joystick.output_vector != Vector2.ZERO:
			last_angle = joystick.output_vector.angle()
		return last_angle
	if _joystick_was_active:
		_joystick_was_active = false
		_mouse_steer_until = 0
	var head := Vector2.ZERO
	var my_id := multiplayer.get_unique_id()
	if snakes_view.has(my_id):
		head = snakes_view[my_id].head_pos
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		last_angle = dir.angle()
		return last_angle
	if Time.get_ticks_msec() <= _mouse_steer_until:
		var mouse := get_global_mouse_position()
		var diff := mouse - head
		if diff.length() >= 8.0:
			last_angle = diff.angle()
			return last_angle
	return last_angle

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_steer_until = Time.get_ticks_msec() + 500

func _is_boosting() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT) or boost_button.boost_pressed

func _check_food_eat(s: SnakeSim) -> void:
	for i in range(foods.size() - 1, -1, -1):
		if s.head_pos.distance_to(foods[i]) < SNAKE_RADIUS + FOOD_RADIUS:
			foods.remove_at(i)
			s.grow(FOOD_VALUE)
			_spawn_food()

func _spawn_food() -> void:
	if foods.size() >= food_max:
		return
	foods.append(Vector2(randf_range(-world_half, world_half), randf_range(-world_half, world_half)))

func _check_death(s: SnakeSim) -> bool:
	if absf(s.head_pos.x) > world_half or absf(s.head_pos.y) > world_half:
		return true
	for id in snakes:
		var t: SnakeSim = snakes[id]
		if t == s:
			continue
		if not t.alive or not t.has_input:
			continue
		if s.head_pos.distance_to(t.head_pos) > t.length + SNAKE_RADIUS * 3.0:
			continue
		for i in range(t.body_points.size() - 1):
			if _dist_to_segment(s.head_pos, t.body_points[i], t.body_points[i + 1]) < SNAKE_RADIUS * 1.7:
				return true
	return false

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

func _kill_snake(s: SnakeSim) -> void:
	s.alive = false
	s.respawn_timer = RESPAWN_TIME
	var pts := s.body_points
	var drop_count := mini(int(s.length / 2.0), pts.size())
	for i in range(0, drop_count):
		var idx := pts.size() - 1 - i
		if idx < 0:
			break
		foods.append(pts[idx])
	s.body_points = PackedVector2Array()

func _find_spawn() -> Vector2:
	for attempt in range(12):
		var pos := Vector2(randf_range(-world_half * 0.7, world_half * 0.7), randf_range(-world_half * 0.7, world_half * 0.7))
		var ok := true
		for id in snakes:
			var t: SnakeSim = snakes[id]
			if t.alive and pos.distance_to(t.head_pos) < 200.0:
				ok = false
				break
		if ok:
			return pos
	return Vector2.ZERO

func _add_snake(peer_id: int, name: String) -> void:
	if snakes.has(peer_id):
		return
	var s := SnakeSim.new()
	s.peer_id = peer_id
	s.display_name = name
	s.color = COLORS[snakes.size() % COLORS.size()]
	s.spawn(_find_spawn())
	snakes[peer_id] = s

func _broadcast_state() -> void:
	var snake_data := []
	for id in snakes:
		snake_data.append(snakes[id].to_dict())
	var payload := {
		"snakes": snake_data,
		"foods": foods,
		"scores": _compute_scores(),
		"world_half": world_half,
	}
	latest_snapshot = payload
	_new_snapshot = true
	_recv_state.rpc(payload)

@rpc("authority", "call_remote", "unreliable_ordered")
func _recv_state(payload: Dictionary) -> void:
	latest_snapshot = payload
	_new_snapshot = true

func _compute_scores() -> Array:
	var arr := []
	for id in snakes:
		var s: SnakeSim = snakes[id]
		if s.alive:
			arr.append({"id": id, "name": s.display_name, "length": s.length})
	arr.sort_custom(func(a, b): return a["length"] > b["length"])
	return arr

func _process(delta: float) -> void:
	if multiplayer.is_server():
		_refresh_lag_status()
	if _new_snapshot:
		_new_snapshot = false
		if not latest_snapshot.is_empty():
			_render_snapshot(latest_snapshot)
	var my_id := multiplayer.get_unique_id()
	if snakes_view.has(my_id):
		var view: SnakeViewSim = snakes_view[my_id]
		camera_pos = camera_pos.lerp(view.head.position, 1.0 - exp(-10.0 * delta))
		camera.position = camera_pos
		var zoom := clampf(1.0 / (1.0 + my_length * 0.0012), 0.55, 1.0)
		camera.zoom = Vector2(zoom, zoom)

func _render_snapshot(payload: Dictionary) -> void:
	var wh := float(payload.get("world_half", world_half))
	if absf(wh - world_half) > 0.5:
		world_half = wh
		background.set_world_half(world_half)
	food_layer.set_positions(payload.get("foods", PackedVector2Array()))
	var snake_list: Array = payload.get("snakes", [])
	var seen := {}
	for sd in snake_list:
		seen[sd["id"]] = true
		_update_snake_view(sd)
	for id in snakes_view.keys():
		if not seen.has(id):
			snakes_view[id].queue_free()
			snakes_view.erase(id)
	_update_leaderboard(payload.get("scores", []), multiplayer.get_unique_id())
	_update_death_overlay(snake_list)
	hud_length.text = "长度: %d" % int(my_length)

func _update_snake_view(sd: Dictionary) -> void:
	var id: int = sd["id"]
	var view: SnakeViewSim
	if not snakes_view.has(id):
		view = SnakeViewSim.new()
		view.snake_color = sd["color"]
		snake_layer.add_child(view)
		snakes_view[id] = view
	else:
		view = snakes_view[id]
	if not sd["alive"]:
		view.visible = false
		return
	view.visible = true
	if id == multiplayer.get_unique_id():
		view.snap_to(sd["head"], sd["points"], sd["angle"])
	else:
		view.update_view(sd["head"], sd["points"], sd["angle"])
	if id == multiplayer.get_unique_id():
		my_length = sd["length"]

func _update_leaderboard(scores: Array, my_id: int) -> void:
	while lb_labels.size() < scores.size() and lb_labels.size() < 8:
		var lbl := Label.new()
		hud_lb.add_child(lbl)
		lb_labels.append(lbl)
	for i in range(lb_labels.size()):
		var lbl := lb_labels[i]
		if i < scores.size():
			lbl.visible = true
			var sc: Dictionary = scores[i]
			var suffix := "  (你)" if sc["id"] == my_id else ""
			lbl.text = "#%d  %s : %d%s" % [i + 1, sc["name"], int(sc["length"]), suffix]
		else:
			lbl.visible = false

func _update_death_overlay(snake_list: Array) -> void:
	var my_id := multiplayer.get_unique_id()
	for sd in snake_list:
		if sd["id"] == my_id:
			if sd["alive"]:
				death_overlay.visible = false
			else:
				death_overlay.visible = true
				var t := float(sd.get("respawn", RESPAWN_TIME))
				death_label.text = "你死了！\n%.1f 秒后重生..." % maxf(t, 0.0)
			return

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		if snakes.has(peer_id):
			_kill_snake(snakes[peer_id])
			snakes.erase(peer_id)
	else:
		if peer_id == 1:
			host_left = true
			death_overlay.visible = true
			death_label.text = "与主机断开连接\n请点击左上角退出游戏"

func _on_player_ready_received(peer_id: int, name: String) -> void:
	if multiplayer.is_server() and not snakes.has(peer_id):
		_add_snake(peer_id, name)

func _on_leave_pressed() -> void:
	Network.leave_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_leave_pressed()
		get_viewport().set_input_as_handled()