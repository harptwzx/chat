extends Control

const RADIUS := 55.0

var ui_alpha := 0.6
var boost_pressed := false

func _ready() -> void:
	ui_alpha = Network.ui_opacity
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	if pressed != boost_pressed:
		boost_pressed = pressed
		queue_redraw()
	accept_event()

func _draw() -> void:
	var center := size * 0.5
	var fill := Color(1, 1, 1, ui_alpha * (0.35 if boost_pressed else 0.16))
	var ring := Color(1, 1, 1, ui_alpha * 0.6)
	draw_circle(center, RADIUS, fill)
	draw_arc(center, RADIUS, 0.0, TAU, 40, ring, 3.0)