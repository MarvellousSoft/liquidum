class_name LevelLister

const INITIAL_UNLOCKED_LEVELS := 3
const MAX_UNSOLVED_LEVELS := 2


static func level_name(section: int, level: int) -> String:
	return "level%02d_%02d" % [section, level]

static func has_section(section: int) -> int:
	return FileManager.has_level_data(section, 1)

static func get_levels_in_section(section: int) -> int:
	var i := 1
	while FileManager.has_level_data(section, i):
		i += 1
	return i - 1


static func get_game_level_data(section : int, level : int):
	if not FileManager.has_level_data(section, level):
		push_error("Not a valid level (section %s - level %s)" % [str(section), str(level)])
	return FileManager.load_level(LevelLister.level_name(section, level))


static func section_complete(section: int) -> bool:
	var count_uncompleted := 0
	for i in range(1, 100):
		if not FileManager.has_level_data(section, i) or count_uncompleted > MAX_UNSOLVED_LEVELS:
			if i == 1:
				# No levels in section
				return false
			break
		var save := FileManager.load_level(LevelLister.level_name(section, i))
		if save == null or not save.is_completed():
			count_uncompleted += 1
	return count_uncompleted <= MAX_UNSOLVED_LEVELS

# Levels 1-return are unlocked in this section. If 0, none is unlocked.
static func get_max_unlocked_level(section: int) -> int:
	if section > 1:
		if not LevelLister.section_complete(section - 1):
			return 0
	var count_completed := 0
	var i := 1
	while FileManager.has_level_data(section, i) and i <= INITIAL_UNLOCKED_LEVELS + count_completed:
		var save := FileManager.load_level(LevelLister.level_name(section, i))
		if save != null and save.is_completed():
			count_completed += 1
		i += 1
	return i - 1


static func count_section_levels(section : int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_level_data(section, level):
			break
		count += 1
	return count


static func count_completed_section_levels(section : int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_level_data(section, level):
			break
		var save := FileManager.load_level(LevelLister.level_name(section, level), FileManager.get_current_profile())
		if save != null and save.is_completed():
			count += 1
	return count


static func count_completed_levels(profile_name: String) -> int:
	var count := 0
	for section in range(1, 50):
		if not FileManager.has_level_data(section, 1):
			break
		for level in range(1, 50):
			if not FileManager.has_level_data(section, level):
				break
			var save := FileManager.load_level(LevelLister.level_name(section, level), profile_name)
			if save != null and save.is_completed():
				count += 1
	return count


static func clear_all_level_saves(profile_name: String) -> void:
	for section in range(1, 50):
		if not FileManager.has_level_data(section, 1):
			break
		for level in range(1, 50):
			if not FileManager.has_level_data(section, level):
				break
			FileManager.clear_level(LevelLister.level_name(section, level), profile_name)


static func count_section_ongoing_solutions(section: int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_level_data(section, level):
			break
		var save := FileManager.load_level(LevelLister.level_name(section, level))
		if save != null and not save.is_solution_empty():
			count += 1
	return count

static func all_campaign_levels_completed() -> bool:
	for section in range(1, 50):
		if not FileManager.has_level_data(section, 1):
			break
		for level in range(1, 50):
			if not FileManager.has_level_data(section, level):
				break
			var save := FileManager.load_level(LevelLister.level_name(section, level))
			if save == null or not save.is_completed():
				return false
	return true
