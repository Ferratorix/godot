class_name IsoCamera
extends Camera2D
## Smooth pan/zoom camera for the isometric farm.
##
## Driven by method calls (pan_by, zoom_at, fling) from the scene
## controller, so it does not depend on any input source.
## * Smooth motion: position/zoom ease towards targets.
## * Inertia: a fling keeps the camera gliding with damping.
## * Bounds: the view centre is clamped to [member world_bounds].
## * Pixel-perfect: when a zoom gesture settles, zoom snaps to a level where
##   one art pixel maps to a whole number of screen pixels (no blurry or
##   uneven pixels).

signal zoom_settled(zoom_level: float)

@export var min_zoom: float = 0.75
@export var max_zoom: float = 4.0
## Higher = snappier follow of the target.
@export var smoothing_speed: float = 14.0
## Inertia damping per second (fraction of velocity lost).
@export var fling_damping: float = 5.0
## Seconds without zoom input before snapping to a pixel-perfect level.
@export var zoom_settle_delay: float = 0.18
@export var pixel_perfect_zoom: bool = true

## World-space rectangle the view centre must stay inside.
var world_bounds: Rect2 = Rect2(-512, -512, 1024, 1024)
var target_position: Vector2
var target_zoom: float = 1.0
var _fling_velocity: Vector2 = Vector2.ZERO
var _zoom_idle_time: float = 0.0
var _zoom_pending_snap: bool = false


func _ready() -> void:
	target_position = position
	target_zoom = zoom.x
	position_smoothing_enabled = false  # We smooth ourselves (pixel snap aware).
	# Rotation / resize changes the stretch factor: re-snap the zoom.
	get_viewport().size_changed.connect(request_pixel_snap)


## Snaps zoom to the nearest pixel-perfect level on the next step.
func request_pixel_snap() -> void:
	_zoom_pending_snap = pixel_perfect_zoom
	_zoom_idle_time = zoom_settle_delay


func _process(delta: float) -> void:
	step(delta)


## Advances smoothing/inertia. Public so tests can drive it deterministically.
func step(delta: float) -> void:
	if _fling_velocity.length_squared() > 1.0:
		target_position += _fling_velocity * delta / zoom.x
		_fling_velocity = _fling_velocity * maxf(0.0, 1.0 - fling_damping * delta)
		target_position = clamp_to_bounds(target_position)
	else:
		_fling_velocity = Vector2.ZERO

	if _zoom_pending_snap:
		_zoom_idle_time += delta
		if _zoom_idle_time >= zoom_settle_delay:
			_zoom_pending_snap = false
			_set_zoom_keep_center(_snapped_zoom(target_zoom))
			zoom_settled.emit(target_zoom)

	var t: float = clampf(smoothing_speed * delta, 0.0, 1.0)
	var new_zoom: float = lerpf(zoom.x, target_zoom, t)
	if absf(new_zoom - target_zoom) < 0.001:
		new_zoom = target_zoom
	zoom = Vector2(new_zoom, new_zoom)
	position = position.lerp(target_position, t)
	if position.distance_squared_to(target_position) < 0.01:
		position = target_position


## Pans by a viewport-space delta (finger movement). Content follows finger.
func pan_by(screen_delta: Vector2) -> void:
	_fling_velocity = Vector2.ZERO
	target_position = clamp_to_bounds(target_position - screen_delta / target_zoom)


## Starts an inertial glide; [param screen_velocity] is in viewport px/s.
func fling(screen_velocity: Vector2) -> void:
	_fling_velocity = -screen_velocity


## Multiplies zoom by [param factor] keeping the world point under
## [param screen_point] (viewport coords) fixed.
func zoom_at(screen_point: Vector2, factor: float) -> void:
	if factor <= 0.0 or not is_finite(factor):
		return
	var world_before: Vector2 = screen_to_world(screen_point)
	target_zoom = clampf(target_zoom * factor, min_zoom, max_zoom)
	var world_after: Vector2 = screen_to_world(screen_point)
	target_position = clamp_to_bounds(target_position + world_before - world_after)
	_zoom_pending_snap = pixel_perfect_zoom
	_zoom_idle_time = 0.0


## Converts a viewport point to world space using the camera *targets*,
## so successive gesture events compose correctly while smoothing.
func screen_to_world(screen_point: Vector2) -> Vector2:
	var half: Vector2 = _viewport_size() * 0.5
	return target_position + (screen_point - half) / target_zoom


func clamp_to_bounds(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, world_bounds.position.x, world_bounds.end.x),
		clampf(p.y, world_bounds.position.y, world_bounds.end.y))


## Instantly jumps to the given view (no smoothing).
func snap_to(world_position: Vector2, zoom_level: float) -> void:
	target_zoom = clampf(zoom_level, min_zoom, max_zoom)
	target_position = clamp_to_bounds(world_position)
	_fling_velocity = Vector2.ZERO
	position = target_position
	zoom = Vector2(target_zoom, target_zoom)


## Ratio between physical window pixels and viewport (canvas) units.
func get_stretch_scale() -> float:
	var vp_size: Vector2 = _viewport_size()
	var window := get_window()
	if window == null or vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return 1.0
	var win: Vector2 = Vector2(window.size)
	return maxf(0.01, minf(win.x / vp_size.x, win.y / vp_size.y))


## Picks the zoom closest to [param zoom_level] such that
## zoom * stretch_scale is a whole number of screen pixels per art pixel,
## staying within [param lo]..[param hi] when possible.
static func compute_pixel_perfect_zoom(zoom_level: float, stretch_scale: float,
		lo: float, hi: float) -> float:
	if stretch_scale <= 0.0:
		return clampf(zoom_level, lo, hi)
	var effective: float = maxf(1.0, roundf(zoom_level * stretch_scale))
	var min_eff: float = ceilf(lo * stretch_scale - 0.0001)
	var max_eff: float = floorf(hi * stretch_scale + 0.0001)
	if min_eff <= max_eff:
		effective = clampf(effective, maxf(1.0, min_eff), maxf(1.0, max_eff))
		return effective / stretch_scale
	return clampf(zoom_level, lo, hi)  # No integer level in range.


func _snapped_zoom(zoom_level: float) -> float:
	return compute_pixel_perfect_zoom(zoom_level, get_stretch_scale(), min_zoom, max_zoom)


func _set_zoom_keep_center(new_zoom: float) -> void:
	target_zoom = new_zoom
	target_position = clamp_to_bounds(target_position)


func _viewport_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp else Vector2(640, 360)
