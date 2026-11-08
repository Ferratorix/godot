extends Node
## Autoload "ProgressionManager": XP, levels, skill points and skills.
##
## Five skill branches are defined (design doc §10); only AGRONOMY and TRADE
## are available in Stage 1, the rest are reported as locked.

signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up(new_level: int)
signal skills_changed
signal state_changed

enum Skill { AGRONOMY, TECHNOLOGY, TRADE, MECHANICS, LIVESTOCK }

const MAX_LEVEL: int = 30
const SKILL_MAX_LEVEL: int = 5
## Branches playable in the current version.
const AVAILABLE_SKILLS: Array[Skill] = [Skill.AGRONOMY, Skill.TRADE]
const SKILL_IDS := {
	Skill.AGRONOMY: "agronomy", Skill.TECHNOLOGY: "technology", Skill.TRADE: "trade",
	Skill.MECHANICS: "mechanics", Skill.LIVESTOCK: "livestock",
}
## Agronomy: growth time -4% per level (subject to the global speed cap).
const AGRONOMY_TIME_PER_LEVEL: float = 0.04
## Trade: sell price +5% per level.
const TRADE_PRICE_PER_LEVEL: float = 0.05
## XP sources.
const XP_PER_PLANTING: int = 1
const COINS_PER_SALE_XP: int = 20

var level: int = 1
## XP accumulated inside the current level.
var xp: int = 0
var skill_points: int = 0
var _skills: Dictionary = {}  # Skill -> int


func reset() -> void:
	level = 1
	xp = 0
	skill_points = 0
	_skills.clear()
	xp_changed.emit(xp, xp_to_next_level(), level)
	skills_changed.emit()
	state_changed.emit()


## XP needed to go from [param from_level] to the next one.
static func xp_for_level(from_level: int) -> int:
	return int(round(20.0 + 15.0 * pow(maxf(0.0, from_level - 1.0), 1.6)))


func xp_to_next_level() -> int:
	return xp_for_level(level)


func is_max_level() -> bool:
	return level >= MAX_LEVEL


## Adds XP, handling multiple level-ups. Returns levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	xp += amount
	var gained := 0
	while not is_max_level() and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		skill_points += 1
		gained += 1
		level_up.emit(level)
	if is_max_level():
		xp = 0
	xp_changed.emit(xp, xp_to_next_level(), level)
	state_changed.emit()
	return gained


func is_plant_unlocked(plant: PlantData) -> bool:
	return plant != null and level >= plant.unlock_level


func is_equipment_unlocked(equipment: EquipmentData) -> bool:
	return equipment != null and level >= equipment.unlock_level


func get_skill_level(skill: Skill) -> int:
	return _skills.get(skill, 0)


func is_skill_available(skill: Skill) -> bool:
	return AVAILABLE_SKILLS.has(skill)


func can_upgrade_skill(skill: Skill) -> bool:
	return is_skill_available(skill) and skill_points > 0 \
		and get_skill_level(skill) < SKILL_MAX_LEVEL


func upgrade_skill(skill: Skill) -> bool:
	if not can_upgrade_skill(skill):
		return false
	skill_points -= 1
	_skills[skill] = get_skill_level(skill) + 1
	skills_changed.emit()
	state_changed.emit()
	return true


## Growth time multiplier from skills (before the global cap).
func get_growth_time_multiplier() -> float:
	return 1.0 - AGRONOMY_TIME_PER_LEVEL * get_skill_level(Skill.AGRONOMY)


func get_sell_price_multiplier() -> float:
	return 1.0 + TRADE_PRICE_PER_LEVEL * get_skill_level(Skill.TRADE)


func get_state() -> Dictionary:
	var skills := {}
	for s: Skill in _skills:
		skills[SKILL_IDS[s]] = _skills[s]
	return {"level": level, "xp": xp, "skill_points": skill_points, "skills": skills}


func apply_state(state: Dictionary) -> void:
	level = clampi(_int(state.get("level", 1)), 1, MAX_LEVEL)
	xp = clampi(_int(state.get("xp", 0)), 0, maxi(0, xp_to_next_level() - 1))
	skill_points = clampi(_int(state.get("skill_points", 0)), 0, MAX_LEVEL)
	_skills.clear()
	var raw: Variant = state.get("skills", {})
	if raw is Dictionary:
		for s: Skill in SKILL_IDS:
			var v := _int(raw.get(SKILL_IDS[s], 0))
			if v > 0:
				_skills[s] = mini(v, SKILL_MAX_LEVEL)
	xp_changed.emit(xp, xp_to_next_level(), level)
	skills_changed.emit()
	state_changed.emit()


static func _int(v: Variant) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) else 0
