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
# For now, extra level sections are always unlocked (no dependencies), but that's not too hard to change
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

func android_payment(section: int) -> String:
	return _config(section).get_value("section", "android_payment", "")

func ios_payment(section: int) -> String:
	return _config(section).get_value("section", "ios_payment", "")

func steam_dlc(section: int) -> int:
	return _config(section).get_value("section", "dlc", -1)

func section_disabled(section: int) -> bool:
	if Global.is_demo:
		return true
	if Global.is_mobile:
		var payment := AdManager.payment
		if OS.get_name() == "Android":
			var purchase := android_payment(section)
			return purchase != "" and (payment == null or payment.purchased.find(purchase) == -1)
		elif OS.get_name() == "iOS":
			var purchase := ios_payment(section)
			return purchase != "" and (payment == null or payment.purchased.find(purchase) == -1)
	else:
		var dlc := steam_dlc(section)
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
	return android_payment(section) == ""

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

# Number of levels that can be always played
func get_disabled_section_free_trial(section: int) -> Array:
	if Global.is_demo:
		return []
	return _config(section).get_value("section", "trial_levels", [1])

func purchase_section(section: int) -> void:
	var id: String
	if OS.get_name() == "Android":
		id = android_payment(section)
	elif OS.get_name() == "iOS":
		id = ios_payment(section)
	if id != "" and AdManager.payment != null:
		print("Purchasing DLC from section %d with id %s" % [section, id])
		await AdManager.payment.do_purchase_dlc(id)
	else:
		print("Purchase for section %d doesn't exist" % [section])

func clear_all_level_saves(profile_name: String) -> void:
	var section := 1
	while FileManager.has_extra_level_data(section, 1):
		var level := 1
		while FileManager.has_extra_level_data(section, level):
			FileManager.clear_level(ExtraLevelLister.level_name(section, level), profile_name)
			level += 1
		section += 1

func flair_text(section: int) -> String:
	if Global.is_mobile and _config(section).has_section_key("flair", "mobile_text"):
		return _config(section).get_value("flair", "mobile_text", "")
	return _config(section).get_value("flair", "text", "")

func flair_color(section: int) -> int:
	return _config(section).get_value("flair", "color", 0)
