extends Control

@onready var name_edit: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/NameEdit
@onready var port_edit: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/PortEdit
@onready var ip_edit: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/IpEdit
@onready var status_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var host_button: Button = $CenterContainer/PanelContainer/VBoxContainer/HostButton
@onready var join_button: Button = $CenterContainer/PanelContainer/VBoxContainer/JoinButton
@onready var size_option: OptionButton = $CenterContainer/PanelContainer/VBoxContainer/SizeOption
@onready var opacity_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/OpacitySlider
@onready var opacity_label: Label = $CenterContainer/PanelContainer/VBoxContainer/OpacityLabel

func _ready() -> void:
	Network.host_started.connect(_on_host_started)
	Network.host_failed.connect(_on_host_failed)
	Network.join_succeeded.connect(_on_join_succeeded)
	Network.join_failed.connect(_on_join_failed)
	Network.peer_disconnected.connect(_on_peer_disconnected)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	port_edit.text_changed.connect(_on_port_text_changed)
	opacity_slider.value_changed.connect(_on_opacity_changed)
	name_edit.text = Network.player_name
	opacity_slider.value = Network.ui_opacity
	_on_opacity_changed(Network.ui_opacity)

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() and peer_id == 1:
		_set_buttons_disabled(false)
		status_label.text = "连接被主机拒绝（服务器繁忙）或已断开"

func _on_port_text_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch.is_valid_int():
			digits += ch
	if digits != new_text:
		port_edit.text = digits
		port_edit.caret_column = digits.length()

func _set_buttons_disabled(v: bool) -> void:
	host_button.disabled = v
	join_button.disabled = v

func _get_name() -> String:
	var nm := name_edit.text.strip_edges()
	if nm.is_empty():
		nm = "玩家" + str(randi_range(100, 999))
	Network.player_name = nm
	return nm

func _get_port() -> int:
	var p := int(port_edit.text.strip_edges())
	if p <= 0 or p > 65535:
		p = Network.DEFAULT_PORT
	return p

func _get_world_half() -> float:
	match size_option.selected:
		0:
			return Network.WORLD_SIZES["small"]
		2:
			return Network.WORLD_SIZES["large"]
		_:
			return Network.WORLD_SIZES["medium"]

func _on_opacity_changed(v: float) -> void:
	Network.ui_opacity = v
	opacity_label.text = "UI 透明度: %d%%" % int(v * 100.0)

func _on_host_pressed() -> void:
	_set_buttons_disabled(true)
	_get_name()
	Network.world_half = _get_world_half()
	status_label.text = "正在创建房间..."
	Network.host_game(_get_port())

func _on_join_pressed() -> void:
	_set_buttons_disabled(true)
	_get_name()
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		status_label.text = "请先输入主机IP"
		_set_buttons_disabled(false)
		return
	status_label.text = "正在连接 %s ..." % ip
	Network.join_game(ip, _get_port())

func _on_host_started(ips: Array) -> void:
	_change_to_game()

func _on_host_failed(reason: String) -> void:
	_set_buttons_disabled(false)
	status_label.text = "创建失败：" + reason

func _on_join_succeeded() -> void:
	status_label.text = "连接成功！进入游戏..."
	_change_to_game()

func _on_join_failed(reason: String) -> void:
	_set_buttons_disabled(false)
	status_label.text = reason

func _change_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")