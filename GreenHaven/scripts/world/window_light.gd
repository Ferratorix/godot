class_name WindowLight
extends Node2D
## Cozy sunbeam from a wall window: additive gradient polygon + slow dust
## motes. Purely decorative; costs a handful of particles.

## Window opening in local coordinates (top-left, top-right, bottom-right,
## bottom-left), already sheared along the wall.
@export var window_quad: PackedVector2Array = PackedVector2Array([
	Vector2(0, 0), Vector2(24, 12), Vector2(24, 42), Vector2(0, 30)])
## Where the light lands, relative to the window.
@export var beam_offset: Vector2 = Vector2(-46, 58)
@export var light_color: Color = Color(1.0, 0.93, 0.72, 0.16)


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var beam := Polygon2D.new()
	beam.material = additive
	beam.polygon = PackedVector2Array([
		window_quad[0], window_quad[1],
		window_quad[2] + beam_offset, window_quad[3] + beam_offset])
	var faded := Color(light_color, 0.0)
	beam.vertex_colors = PackedColorArray([light_color, light_color, faded, faded])
	add_child(beam)

	var dust := CPUParticles2D.new()
	dust.material = additive
	dust.amount = 14
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.position = (window_quad[0] + window_quad[2] + beam_offset) * 0.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(18, 22)
	dust.direction = Vector2(-0.4, 1.0)
	dust.spread = 30.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.0
	dust.color = Color(1.0, 0.95, 0.8, 0.5)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.5, Color(1, 1, 1, 1))
	dust.color_ramp = fade
	add_child(dust)
