extends LevelLister


func level_name(section: int, level: int) -> String:
	return "extra_level%02d_%02d" % [section, level]

func has_section(section: int, show_hidden := false) -> int:
	if FileManager.has_extra_level_data(section, 1):
		return show_hidden or Global.is_dev_mode() or not _config(section).get_value('section', 'hidden', false)
	return false

func count_all_game_sections(show_hidden := false) -> int:
	var i := 1
	while has_section(i, show_hidden):
		i += 1
	return i - 1

var _section_config: Array[ConfigFile] = []

func _config(section: int) -> ConfigFile:
	while _section_config.size() < section:
		_section_config.append(null)
	if _section_config[section - 1] == null:
		var c := ConfigFile.new()
		c.load("res://database/extra_levels/%02d/config.ini" % section)
		_section_config[section - 1] = c
	return _section_config[section - 1]

func get_initial_unlocked_levels(section: int) -> int:
	return _config(section).get_value("section", "initial_unlocked", CampaignLevelLister.INITIAL_UNLOCKED_LEVELS)

# Levels 1-return are unlocked in this section. If 0, none is unlocked.
# For now, extra level sections are always unlocked, but that's not too hard to change
func get_max_unlocked_level(section: int) -> int:
	var count_completed := 0
	var i := 1
	var initial_unlock := get_initial_unlocked_levels(section)
	while FileManager.has_extra_level_data(section, i) and i <= initial_unlock + count_completed:
		var save := FileManager.load_level(ExtraLevelLister.level_name(section, i))
		if save != null and save.is_completed():
			count_completed += 1
		i += 1
	return i - 1


func count_section_levels(section: int) -> int:
	var i := 1
	while FileManager.has_extra_level_data(section, i):
		i += 1
	return i - 1

func get_max_unlocked_levels(_section: int) -> int:
	return CampaignLevelLister.MAX_UNSOLVED_LEVELS

func count_completed_section_levels(section: int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_extra_level_data(section, level):
			break
		var save := FileManager.load_level(ExtraLevelLister.level_name(section, level))
		if save != null and save.is_completed():
			count += 1
	return count

func count_section_ongoing_solutions(section: int) -> int:
	var level := 1
	var count := 0
	while FileManager.has_extra_level_data(section, level):
		var save := FileManager.load_level(ExtraLevelLister.level_name(section, level))
		if save != null and not save.is_solution_empty():
			count += 1
		level += 1
	return count

func get_level_user_save(section : int, level : int) -> UserLevelSaveData:
	if not FileManager.has_extra_level_data(section, level):
		push_error("Not a valid extra level (section %s - level %s)" % [str(section), str(level)])
	return FileManager.load_level(ExtraLevelLister.level_name(section, level))

func endless_level_name(section: int) -> String:
	return "endless_%02d" % section

func get_endless_user_save(section: int) -> UserLevelSaveData:
	return FileManager.load_level(ExtraLevelLister.endless_level_name(section))

func get_level_data(section: int, level: int) -> LevelData:
	return FileManager.load_extra_level_data(section, level)

func level_stat(section: int, level: int) -> String:
	return "el%02d_%02d" % [section, level]

func section_name(section: int) -> String:
	return _config(section).get_value("section", "name", "No name")

func _android_payment(section: int) -> String:
	return _config(section).get_value("section", "android_payment", "")

func section_disabled(section: int) -> bool:
	if Global.is_mobile:
		# TODO: Payments
		pass
	else:
		var dlc: int = _config(section).get_value("section", "dlc", -1)
		if dlc != -1 and (not SteamManager.enabled or not SteamManager.steam.isDLCInstalled(dlc)):
			return true
	return false

func section_endless_flavor(section: int) -> int:
	var flavor_name: String = _config(section).get_value("section", "endless_flavor", "")
	if flavor_name.is_empty():
		return -1
	else:
		return RandomFlavors.Flavor.get(flavor_name, -1)

func is_hard(section: int, level: int) -> bool:
	return level == -1 or level in _config(section).get_value("section", "hard_levels", [])

func is_free(section: int) -> bool:
	return _android_payment(section) == ""

func count_completed_levels(profile_name: String) -> int:
	var count := 0
	for i in range(1, 100):
		if not ExtraLevelLister.has_section(i):
			break
		for j in range(1, 100):
			if not FileManager.has_extra_level_data(i, j):
				break
			var save := FileManager.load_level(ExtraLevelLister.level_name(i, j), profile_name)
			if save != null and save.is_completed():
				count += 1
	return count
