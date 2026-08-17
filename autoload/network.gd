extends Node

signal host_started(local_ips: Array)
signal host_failed(reason: String)
signal join_succeeded
signal join_failed(reason: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal player_ready_received(peer_id: int, player_name: String)

const DEFAULT_PORT := 8910
const MAX_PLAYERS := 16
const LAG_FPS_THRESHOLD := 40.0
const LAG_WINDOW := 3.0
const WORLD_SIZES := {
	"small": 600.0,
	"medium": 1000.0,
	"large": 1500.0,
}

var player_name := "玩家"
var world_half := 1000.0
var ui_opacity := 0.6
var last_port := DEFAULT_PORT
var server_laggy := false
var pending_ready: Dictionary = {}

var _fps_sum := 0.0
var _fps_count := 0
var _fps_elapsed := 0.0

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _process(delta: float) -> void:
	_fps_sum += Engine.get_frames_per_second()
	_fps_count += 1
	_fps_elapsed += delta
	if _fps_elapsed >= LAG_WINDOW:
		var avg := _fps_sum / float(maxi(_fps_count, 1))
		server_laggy = avg < LAG_FPS_THRESHOLD
		if server_laggy:
			print("检测到帧率偏低（%.0f FPS），已暂停接受新玩家" % avg)
		_fps_sum = 0.0
		_fps_count = 0
		_fps_elapsed = 0.0

func is_laggy() -> bool:
	return server_laggy

func _kick_peer(peer_id: int, reason: String) -> void:
	print("已拒绝玩家进入（%s）：%s" % [peer_id, reason])
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.disconnect_peer(peer_id)

func host_game(port: int = DEFAULT_PORT) -> void:
	last_port = port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		var reason := "端口 %d 无法监听" % port
		if err == ERR_ALREADY_IN_USE:
			reason += "（已被其他程序占用，请更换端口）"
		host_failed.emit(reason)
		return
	multiplayer.multiplayer_peer = peer
	var ips := get_local_ips()
	print("贪吃蛇大作战 主机已启动，本机局域网IP：", ips, "  端口：", port)
	host_started.emit(ips)

func join_game(ip: String, port: int = DEFAULT_PORT) -> void:
	last_port = port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		join_failed.emit("无法创建客户端连接")
		return
	multiplayer.multiplayer_peer = peer

func leave_game() -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer != null:
		multiplayer.multiplayer_peer = null
		peer.close()
	pending_ready.clear()

func get_local_ips() -> Array:
	var v4: Array = []
	var v6: Array = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("127.") or ip == "::1" or ip.begins_with("fe80:"):
			continue
		if ":" in ip:
			v6.append(ip)
		else:
			v4.append(ip)
	return v4 + v6

func _on_connected_to_server() -> void:
	join_succeeded.emit()

func _on_connection_failed() -> void:
	join_failed.emit("连接失败：找不到主机（请检查IP与端口）")

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server() and is_laggy():
		_kick_peer(peer_id, "服务器当前帧率过低")
		return
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _player_ready(player_name_sent: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if is_laggy():
		_kick_peer(sender, "服务器当前帧率过低")
		return
	pending_ready[sender] = player_name_sent
	player_ready_received.emit(sender, player_name_sent)