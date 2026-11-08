class_name CellHighlight
extends Node2D
## Draws a pixel-style diamond outline on one or more grid cells
## (selection marker and placement preview).

const SELECT_COLOR := Color(1.0, 0.96, 0.78, 0.95)
const VALID_COLOR := Color(0.62, 0.9, 0.52, 0.95)
const INVALID_COLOR := Color(0.95, 0.42, 0.36, 0.95)

var _centers: PackedVector2Array = PackedVector2Array()
var _half_size: Vector2 = Vector2(16, 8)
var _color: Color = SELECT_COLOR
var _time: float = 0.0


func _process(delta: float) -> void:
	if _centers.is_empty():
		return
	_time += delta
	queue_redraw()  # Gentle pulse; only runs while something is shown.


func show_cells(centers: PackedVector2Array, tile_size: Vector2, color: Color) -> void:
	_centers = centers
	_half_size = tile_size * 0.5
	_color = color
	visible = true
	queue_redraw()


func clear() -> void:
	_centers = PackedVector2Array()
	visible = false
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.75 + 0.25 * sin(_time * 5.0)
	var c := Color(_color, _color.a * pulse)
	var fill := Color(_color, 0.18 * pulse)
	for center in _centers:
		var pts := PackedVector2Array([
			center + Vector2(0, -_half_size.y), center + Vector2(_half_size.x, 0),
			center + Vector2(0, _half_size.y), center + Vector2(-_half_size.x, 0),
		])
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, c, 1.0)
