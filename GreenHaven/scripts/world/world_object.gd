class_name WorldObject
extends Node2D
## Visual representation of one placed object on the iso grid.
##
## Pure view: it does not own occupancy (PlacementGrid does) or gameplay
## state (future farming/equipment systems). Its node position is the
## footprint centre, which makes Y-sorting by position correct.

const SELECT_TINT := Color(1.12, 1.12, 1.0)
const VALID_TINT := Color(0.75, 1.15, 0.75, 0.85)
const INVALID_TINT := Color(1.25, 0.6, 0.55, 0.85)

var data: PlaceableData
var instance_key: StringName
var cell: Vector2i
var is_selected: bool = false

const READY_ICON: Texture2D = preload("res://assets/placeholder/ui/icon_ready.png")
## Plant soil line sits this many px above the sprite's bottom edge.
const PLANT_SOIL_OFFSET: Vector2 = Vector2(-6, -12)

@onready var sprite: Sprite2D = $Sprite
var _tween: Tween
var _plant_sprites: Array[Sprite2D] = []
var _ready_icon: Sprite2D
var _glow: Polygon2D
var _ready_tween: Tween


func setup(placeable: PlaceableData, key: StringName, at_cell: Vector2i) -> void:
	data = placeable
	instance_key = key
	cell = at_cell
	name = String(key)
	if sprite == null:
		sprite = $Sprite  # setup() may run before _ready().
	sprite.texture = placeable.texture
	sprite.centered = false
	sprite.offset = -placeable.texture_anchor
	_build_slot_visuals()


func has_grow_slots() -> bool:
	return data != null and data.grow_slots > 0


## Shows each slot's plant at its current growth stage, the "ready" marker
## and the LED glow. Cheap: a few sprites, called on change and once a second.
func refresh_plants(farm: FarmState, now_unix: float) -> void:
	if not has_grow_slots():
		return
	var any_ready := false
	for i in _plant_sprites.size():
		var p := farm.get_plant(instance_key, i)
		var s := _plant_sprites[i]
		if p == null or p.get_data() == null:
			s.visible = false
			continue
		var stage := p.get_stage(now_unix)
		s.texture = p.get_data().stage_textures[stage]
		s.visible = true
		any_ready = any_ready or stage == PlantData.Stage.MATURE
	_set_ready_marker(any_ready)
	_glow.visible = farm.has_lighting()


func _build_slot_visuals() -> void:
	if not has_grow_slots() or not _plant_sprites.is_empty():
		return
	_glow = Polygon2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	var h := data.texture_anchor.y - 6.0
	_glow.polygon = PackedVector2Array([Vector2(-14, -h), Vector2(14, -h), Vector2(14, 0), Vector2(-14, 0)])
	var c := Color(0.85, 0.75, 1.0, 0.14)
	_glow.vertex_colors = PackedColorArray([c, c, Color(c, 0.0), Color(c, 0.0)])
	_glow.visible = false
	sprite.add_child(_glow)
	for pos in data.slot_positions:
		var s := Sprite2D.new()
		s.centered = false
		s.position = pos
		s.offset = PLANT_SOIL_OFFSET
		s.visible = false
		sprite.add_child(s)
		_plant_sprites.append(s)
	_ready_icon = Sprite2D.new()
	_ready_icon.texture = READY_ICON
	_ready_icon.position = Vector2(0, -data.texture_anchor.y - 8)
	_ready_icon.visible = false
	sprite.add_child(_ready_icon)


func _set_ready_marker(show_it: bool) -> void:
	if _ready_icon.visible == show_it:
		return
	_ready_icon.visible = show_it
	if _ready_tween and _ready_tween.is_valid():
		_ready_tween.kill()
	var base := Vector2(0, -data.texture_anchor.y - 8)
	_ready_icon.position = base
	if show_it:
		_ready_tween = create_tween().set_loops()
		_ready_tween.tween_property(_ready_icon, "position", base + Vector2(0, -3), 0.5) \
			.set_trans(Tween.TRANS_SINE)
		_ready_tween.tween_property(_ready_icon, "position", base, 0.5).set_trans(Tween.TRANS_SINE)


## True if [param world_point] hits a non-transparent pixel of the sprite.
func hit_test(world_point: Vector2) -> bool:
	if sprite.texture == null:
		return false
	var local: Vector2 = sprite.to_local(world_point)
	if not sprite.get_rect().has_point(local):
		return false
	return sprite.is_pixel_opaque(local)


func set_selected(selected: bool) -> void:
	if selected == is_selected:
		return
	is_selected = selected
	sprite.modulate = SELECT_TINT if selected else Color.WHITE
	if selected:
		_bounce(Vector2(1.08, 0.92))


## Visual state while the object is being dragged.
func set_drag_preview(active: bool, valid: bool = true) -> void:
	if not active:
		sprite.modulate = SELECT_TINT if is_selected else Color.WHITE
		z_index = 0
		return
	sprite.modulate = VALID_TINT if valid else INVALID_TINT
	z_index = 1  # Float above neighbours while carried.


func play_place_animation() -> void:
	sprite.position = Vector2(0, -6)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(sprite, "position", Vector2.ZERO, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_bounce.bind(Vector2(1.12, 0.88)))


func _bounce(squash: Vector2) -> void:
	_kill_tween()
	sprite.scale = squash
	_tween = create_tween()
	_tween.tween_property(sprite, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
