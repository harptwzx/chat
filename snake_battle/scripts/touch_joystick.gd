extends Control

const DEADZONE := 0.2
const KNOB_RADIUS := 44.0
const BASE_RADIUS := 88.0

var ui_alpha := 0.6
var is_active := false
var output_vector := Vector2.ZERO

var _touch_index := -1
var _knob_offset := Vector2.ZERO

func _ready() -> void:
	ui_alpha = Network.ui_opacity
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				is_active = true
				_update_knob(event.position)
		else:
			if event.index == _touch_index:
				_touch_index = -1
				_knob_offset = Vector2.ZERO
				output_vector = Vector2.ZERO
				is_active = false
				queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_knob(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_active:
					_touch_index = 0
					is_active = true
					_update_knob(event.position)
			else:
				_touch_index = -1
				_knob_offset = Vector2.ZERO
				output_vector = Vector2.ZERO
				is_active = false
				queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		if is_active:
			_update_knob(event.position)
		accept_event()

func _update_knob(pos: Vector2) -> void:
	var center := size * 0.5
	var delta := pos - center
	var max_len := BASE_RADIUS * 0.6
	if delta.length() > max_len:
		delta = delta.normalized() * max_len
	_knob_offset = delta
	var raw := _knob_offset / max_len
	if raw.length() < DEADZONE:
		output_vector = Vector2.ZERO
	else:
		output_vector = raw.normalized()
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var base_col := Color(1, 1, 1, ui_alpha * 0.16)
	var ring_col := Color(1, 1, 1, ui_alpha * 0.5)
	var knob_col := Color(1, 1, 1, ui_alpha * 0.45)
	draw_circle(center, BASE_RADIUS, base_col)
	draw_arc(center, BASE_RADIUS, 0.0, TAU, 48, ring_col, 3.0)
	draw_circle(center + _knob_offset, KNOB_RADIUS, knob_col)
	draw_arc(center + _knob_offset, KNOB_RADIUS, 0.0, TAU, 32, ring_col, 2.0)