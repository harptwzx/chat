extends Node2D

const FOOD_RADIUS := 5.0
const FOOD_COLOR := Color(0.35, 0.80, 0.45)
const CIRCLE_SEGMENTS := 16

var positions := PackedVector2Array()

var _multimesh: MultiMesh
var _mm: MultiMeshInstance2D

func _ready() -> void:
	var mesh := _make_circle_mesh(FOOD_RADIUS, CIRCLE_SEGMENTS, FOOD_COLOR)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.mesh = mesh
	_multimesh.instance_count = 0
	_mm = MultiMeshInstance2D.new()
	_mm.multimesh = _multimesh
	add_child(_mm)

func _make_circle_mesh(radius: float, segments: int, color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	colors.append(color)
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		verts.append(Vector3(cos(a), sin(a), 0.0) * radius)
		colors.append(color)
	for i in range(segments):
		idx.append(0)
		idx.append(i + 1)
		idx.append((i + 1) % segments + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func set_positions(p: PackedVector2Array) -> void:
	if p == positions:
		return
	positions = p.duplicate()
	_update_multimesh()

func _update_multimesh() -> void:
	var n := positions.size()
	_multimesh.instance_count = n
	var t := Transform2D()
	for i in range(n):
		t.origin = positions[i]
		_multimesh.set_instance_transform_2d(i, t)
	_mm.visible = n > 0