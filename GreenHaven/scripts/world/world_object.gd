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

@onready var sprite: Sprite2D = $Sprite
var _tween: Tween


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
