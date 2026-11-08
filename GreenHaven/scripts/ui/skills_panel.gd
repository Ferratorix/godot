class_name SkillsPanel
extends GamePanel
## Character level and skill branches (2 playable, 3 reserved).

var SKILL_KEYS := {
	ProgressionManager.Skill.AGRONOMY: "SKILL_AGRONOMY",
	ProgressionManager.Skill.TECHNOLOGY: "SKILL_TECHNOLOGY",
	ProgressionManager.Skill.TRADE: "SKILL_TRADE",
	ProgressionManager.Skill.MECHANICS: "SKILL_MECHANICS",
	ProgressionManager.Skill.LIVESTOCK: "SKILL_LIVESTOCK",
}


func _init() -> void:
	super._init()
	set_title("UI_SKILLS")


func refresh() -> void:
	if not visible:
		return
	UiKit.clear(content)
	var pm := ProgressionManager
	var header := tr("UI_LEVEL_FMT") % pm.level
	if not pm.is_max_level():
		header += "   " + tr("UI_XP_FMT") % [pm.xp, pm.xp_to_next_level()]
	content.add_child(UiKit.label(header, 12, UiKit.TITLE_COLOR))
	content.add_child(UiKit.label(tr("UI_SKILL_POINTS_FMT") % pm.skill_points, 11))
	content.add_child(UiKit.separator())
	for skill: int in SKILL_KEYS:
		var key: String = SKILL_KEYS[skill]
		var lvl := pm.get_skill_level(skill)
		var subtitle := tr(key + "_DESC")
		var action: Button
		if pm.is_skill_available(skill):
			subtitle += "\n" + tr("UI_SKILL_LEVEL_FMT") % [lvl, ProgressionManager.SKILL_MAX_LEVEL]
			var label_text := tr("UI_MAXED") if lvl >= ProgressionManager.SKILL_MAX_LEVEL else tr("UI_UPGRADE")
			action = UiKit.button(label_text, _upgrade.bind(skill), 84, pm.can_upgrade_skill(skill))
		else:
			action = UiKit.button(tr("UI_LOCKED_STAGE"), Callable(), 84, false)
		content.add_child(UiKit.row(null, tr(key), subtitle, null, action))
	content.add_child(UiKit.separator())
	content.add_child(UiKit.label(tr("UI_UNLOCKS_TITLE"), 11, UiKit.TITLE_COLOR))
	for plant in GameCatalog.all_plants():
		if not pm.is_plant_unlocked(plant):
			content.add_child(UiKit.label("%s — %s" % [tr(plant.name_key),
				tr("UI_UNLOCK_LEVEL_FMT") % plant.unlock_level], 9, UiKit.MUTED_COLOR))


func _upgrade(skill: int) -> void:
	ProgressionManager.upgrade_skill(skill)
	refresh()
