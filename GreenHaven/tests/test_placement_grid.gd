extends GHTestCase
## PlacementGrid: occupancy rules and serialization.


func test_place_and_occupancy() -> void:
	var g := PlacementGrid.new(Vector2i(4, 3))
	check(g.place(&"a", &"rack", Vector2i(1, 1), Vector2i.ONE))
	check_eq(g.get_owner_at(Vector2i(1, 1)), &"a")
	check_eq(g.get_owner_at(Vector2i(0, 0)), &"")
	check(not g.place(&"b", &"rack", Vector2i(1, 1), Vector2i.ONE), "overlap rejected")
	check(not g.place(&"a", &"rack", Vector2i(2, 2), Vector2i.ONE), "duplicate key rejected")


func test_bounds() -> void:
	var g := PlacementGrid.new(Vector2i(4, 3))
	check(not g.can_place(Vector2i(-1, 0), Vector2i.ONE))
	check(not g.can_place(Vector2i(4, 0), Vector2i.ONE))
	check(not g.can_place(Vector2i(3, 2), Vector2i(2, 1)), "multi-cell overflow")
	check(g.can_place(Vector2i(2, 1), Vector2i(2, 2)))
	check(not g.can_place(Vector2i(0, 0), Vector2i(0, 1)), "empty footprint")


func test_move() -> void:
	var g := PlacementGrid.new(Vector2i(4, 4))
	g.place(&"a", &"x", Vector2i(0, 0), Vector2i(2, 1))
	g.place(&"b", &"x", Vector2i(3, 3), Vector2i.ONE)
	check(g.move(&"a", Vector2i(1, 0)), "may overlap own cells while moving")
	check_eq(g.get_owner_at(Vector2i(0, 0)), &"", "old cell freed")
	check_eq(g.get_owner_at(Vector2i(2, 0)), &"a")
	check(not g.move(&"a", Vector2i(3, 3)), "blocked by b / out of bounds")
	check_eq(g.get_origin(&"a"), Vector2i(1, 0), "failed move keeps position")
	check(not g.move(&"missing", Vector2i(0, 0)))


func test_remove() -> void:
	var g := PlacementGrid.new(Vector2i(2, 2))
	g.place(&"a", &"x", Vector2i(0, 0), Vector2i.ONE)
	check(g.remove(&"a"))
	check_eq(g.object_count(), 0)
	check(g.can_place(Vector2i(0, 0), Vector2i.ONE))
	check(not g.remove(&"a"))


func test_serialisation_roundtrip() -> void:
	var g := PlacementGrid.new(Vector2i(5, 4))
	g.place(&"rack_1", &"hydro_rack_basic", Vector2i(1, 2), Vector2i.ONE)
	g.place(&"table_1", &"work_table", Vector2i(3, 0), Vector2i(2, 1))
	var json := JSON.stringify(g.to_dict())
	var restored := PlacementGrid.from_dict(JSON.parse_string(json))
	check_eq(restored.size, Vector2i(5, 4))
	check_eq(restored.object_count(), 2)
	check_eq(restored.get_owner_at(Vector2i(4, 0)), &"table_1")
	check_eq(restored.get_origin(&"rack_1"), Vector2i(1, 2))


func test_corrupt_data_is_skipped() -> void:
	var data := {"w": 3, "h": 3, "objects": [
		{"key": "ok", "data_id": "x", "x": 0, "y": 0, "w": 1, "h": 1},
		{"key": "overlap", "data_id": "x", "x": 0, "y": 0, "w": 1, "h": 1},
		{"key": "outside", "data_id": "x", "x": 9, "y": 9, "w": 1, "h": 1},
		"garbage",
	]}
	var g := PlacementGrid.from_dict(data)
	check_eq(g.object_count(), 1)
	check(PlacementGrid.from_dict({"objects": "nope"}).object_count() == 0)
