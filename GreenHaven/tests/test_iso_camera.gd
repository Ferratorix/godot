extends GHTestCase
## IsoCamera: zoom anchoring, bounds and pixel-perfect snapping.

var cam: IsoCamera


func before_each() -> void:
	cam = IsoCamera.new()
	tree.root.add_child(cam)
	cam.world_bounds = Rect2(-200, -200, 400, 400)
	cam.snap_to(Vector2.ZERO, 1.0)


func after_each() -> void:
	cam.queue_free()


func test_pixel_perfect_zoom_math() -> void:
	# Window 2x the viewport: zoom 1.3 -> 2.6 px per art px -> snaps to 3.
	check_near(IsoCamera.compute_pixel_perfect_zoom(1.3, 2.0, 0.5, 4.0), 1.5)
	check_near(IsoCamera.compute_pixel_perfect_zoom(1.2, 2.0, 0.5, 4.0), 1.0)
	# Fractional stretch (e.g. 1080p phone on a 360p base = 3.0, 2340x1080 -> 3.0).
	check_near(IsoCamera.compute_pixel_perfect_zoom(0.9, 3.0, 0.5, 4.0), 1.0)
	# Never below one screen pixel per art pixel.
	check_near(IsoCamera.compute_pixel_perfect_zoom(0.1, 2.0, 0.1, 4.0), 0.5)
	# Respects max zoom.
	check_near(IsoCamera.compute_pixel_perfect_zoom(9.0, 2.0, 0.5, 4.0), 4.0)
	# Result is always an integer pixel ratio.
	for z: float in [0.77, 1.1, 1.9, 2.4, 3.3]:
		var r := IsoCamera.compute_pixel_perfect_zoom(z, 2.25, 0.5, 4.0)
		check_near(fmod(r * 2.25, 1.0), 0.0, 0.0001, "integer ratio for %s" % z)


func test_zoom_keeps_point_under_finger() -> void:
	var p := Vector2(500, 300)
	var before := cam.screen_to_world(p)
	cam.zoom_at(p, 2.0)
	check_near(cam.target_zoom, 2.0)
	var after := cam.screen_to_world(p)
	check(before.distance_to(after) < 0.001, "%s vs %s" % [before, after])


func test_zoom_limits() -> void:
	cam.zoom_at(Vector2.ZERO, 100.0)
	check_near(cam.target_zoom, cam.max_zoom)
	cam.zoom_at(Vector2.ZERO, 0.0001)
	check_near(cam.target_zoom, cam.min_zoom)
	cam.zoom_at(Vector2.ZERO, NAN)
	check_near(cam.target_zoom, cam.min_zoom, 0.0001, "NaN ignored")


func test_pan_follows_finger_and_is_bounded() -> void:
	cam.pan_by(Vector2(50, 0))  # Finger moves right -> view moves left.
	check_eq(cam.target_position, Vector2(-50, 0))
	cam.pan_by(Vector2(-10000, -10000))
	check_eq(cam.target_position, Vector2(200, 200), "clamped")


func test_smoothing_converges_and_fling_decays() -> void:
	cam.pan_by(Vector2(-100, 0))
	for i in 60:
		cam.step(1.0 / 60.0)
	check(cam.position.distance_to(cam.target_position) < 0.5, "converged")
	cam.fling(Vector2(-600, 0))
	for i in 120:
		cam.step(1.0 / 60.0)
	var stopped := cam.target_position
	cam.step(1.0 / 60.0)
	check(cam.target_position.distance_to(stopped) < 0.01, "inertia stops")
	check(cam.target_position.x > 100.0, "inertia moved the view")
