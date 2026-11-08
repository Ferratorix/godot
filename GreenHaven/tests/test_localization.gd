extends GHTestCase
## Every key exists in every language; Russian is the default.

const LANGS := ["ru", "en"]


func _keys(lang: String) -> PackedStringArray:
	var keys := PackedStringArray()
	var f := FileAccess.open("res://data/localization/%s.po" % lang, FileAccess.READ)
	if f == null:
		fail("missing %s.po" % lang)
		return keys
	for line in f.get_as_text().split("\n"):
		if line.begins_with("msgid \"") and line != "msgid \"\"":
			keys.append(line.trim_prefix("msgid \"").trim_suffix("\""))
	return keys


func test_languages_have_same_keys() -> void:
	var ru := _keys("ru")
	check(ru.size() > 10)
	for lang: String in LANGS:
		var other := _keys(lang)
		for k in ru:
			check(other.has(k), "%s missing in %s" % [k, lang])
		check_eq(other.size(), ru.size(), lang)


func test_default_locale_is_russian() -> void:
	check(TranslationServer.get_locale().begins_with("ru"))
	check_eq(tr("UI_MOVE"), "Переместить")


func test_placeable_texts_are_translated() -> void:
	for file in DirAccess.get_files_at("res://resources/placeables/"):
		if not file.ends_with(".tres"):
			continue
		var data: PlaceableData = load("res://resources/placeables/" + file)
		check(data.is_valid(), file)
		check(tr(data.name_key) != data.name_key, "name key of " + file)
		check(tr(data.description_key) != data.description_key, "desc key of " + file)
