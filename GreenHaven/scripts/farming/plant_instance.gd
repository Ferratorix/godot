class_name PlantInstance
extends RefCounted
## One planted crop in a grow slot. State is fully described by timestamps:
## nothing ticks; stage/progress are derived from TimeManager time on demand,
## so growth continues while the app is closed.

var uid: int = 0
var plant_id: StringName
var planted_at: float = 0.0
var ready_at: float = 0.0
## Expected harvest incl. yield bonus (fraction is carried between harvests).
var yield_amount: float = 1.0
## Snapshot for the UI ("-20% time").
var time_multiplier: float = 1.0


static func create(plant: PlantData, now_unix: float, modifiers: ProductionModifiers,
		new_uid: int) -> PlantInstance:
	var p := PlantInstance.new()
	p.uid = new_uid
	p.plant_id = plant.id
	p.planted_at = now_unix
	p.ready_at = now_unix + modifiers.apply_to_duration(plant.grow_time_sec)
	p.yield_amount = modifiers.apply_to_yield(plant.yield_amount)
	p.time_multiplier = modifiers.time_multiplier
	return p


func get_data() -> PlantData:
	return GameCatalog.plant(plant_id)


func duration() -> float:
	return maxf(0.0, ready_at - planted_at)


## 0..1, never outside the range.
func progress(now_unix: float) -> float:
	var d := duration()
	if d <= 0.0:
		return 1.0
	return clampf((now_unix - planted_at) / d, 0.0, 1.0)


func is_ready(now_unix: float) -> bool:
	return now_unix >= ready_at


func remaining(now_unix: float) -> float:
	return maxf(0.0, ready_at - now_unix)


## Growth stage 0..4: four equal growing phases, MATURE only when ready.
func get_stage(now_unix: float) -> int:
	if is_ready(now_unix):
		return PlantData.Stage.MATURE
	return mini(PlantData.Stage.ADULT, int(progress(now_unix) * 4.0))


func to_dict() -> Dictionary:
	return {
		"uid": uid, "plant": String(plant_id), "planted_at": planted_at,
		"ready_at": ready_at, "yield": yield_amount, "time_mult": time_multiplier,
	}


## Restores and repairs saved data. Returns null for unknown crops.
## Broken timestamps restart the cycle at [param now_unix] with the base
## duration rather than granting an instant harvest.
static func from_dict(d: Dictionary, now_unix: float) -> PlantInstance:
	var plant := GameCatalog.plant(StringName(str(d.get("plant", ""))))
	if plant == null:
		return null
	var p := PlantInstance.new()
	p.plant_id = plant.id
	p.uid = int(_num(d.get("uid"), 0.0))
	p.planted_at = _num(d.get("planted_at"), -1.0)
	p.ready_at = _num(d.get("ready_at"), -1.0)
	p.time_multiplier = clampf(_num(d.get("time_mult"), 1.0),
		ProductionModifiers.MIN_TIME_MULTIPLIER, 1.0)
	var max_yield := plant.yield_amount * (1.0 + ProductionModifiers.MAX_YIELD_BONUS)
	p.yield_amount = clampf(_num(d.get("yield"), plant.yield_amount), 0.0, max_yield)
	var max_duration := float(plant.grow_time_sec)
	var timestamps_ok := TimeManager.is_valid_timestamp(p.planted_at) \
		and TimeManager.is_valid_timestamp(p.ready_at) \
		and p.ready_at >= p.planted_at \
		and p.ready_at - p.planted_at <= max_duration + 1.0 \
		and p.planted_at <= now_unix + 60.0
	if not timestamps_ok:
		push_warning("PlantInstance: repaired invalid timestamps for %s" % plant.id)
		p.planted_at = now_unix
		p.ready_at = now_unix + max_duration
	return p


static func _num(v: Variant, fallback: float) -> float:
	if (v is int or v is float) and is_finite(float(v)):
		return float(v)
	return fallback
