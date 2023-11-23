class_name LevelLister

static func level_name(section: int, level: int) -> String:
	return "level%02d_%02d" % [section, level]

static func section_complete(section: int) -> bool:
	var count_uncompleted := 0
	for i in 100:
		if not FileManager.has_level_data(section, i) or count_uncompleted > 2:
			break
		var save := FileManager.load_level(LevelLister.level_name(section, i))
		if save == null or not save.completed():
			count_uncompleted += 1
	return count_uncompleted <= 2

# Levels 1-return are unlocked in this section. If 0, none is unlocked.
static func get_max_unlocked_level(section: int) -> int:
	if section > 1:
		if not LevelLister.section_complete(section - 1):
			return 0
	var count_completed := 0
	var i := 1
	while FileManager.has_level_data(section, i) and i <= 3 + count_completed:
		var save := FileManager.load_level(LevelLister.level_name(section, i))
		if save != null and save.completed():
			count_completed += 1
		i += 1
	return i - 1
