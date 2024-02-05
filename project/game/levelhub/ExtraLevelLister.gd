extends LevelLister


func level_name(section: int, level: int) -> String:
	return "extra_level%02d_%02d" % [section, level]

func has_section(section: int) -> int:
	return FileManager.has_extra_level_data(section, 1)

func count_all_game_sections() -> int:
	var i := 1
	while has_section(i):
		i += 1
	return i - 1

# Levels 1-return are unlocked in this section. If 0, none is unlocked.
# For now, extra level sections are always unlocked, but that's not too hard to change
func get_max_unlocked_level(section: int) -> int:
	var count_completed := 0
	var i := 1
	var initial_unlock = CampaignLevelLister.INITIAL_UNLOCKED_LEVELS
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
		if not FileManager.has_campaign_level(section, level):
			break
		var save := FileManager.load_level(ExtraLevelLister.level_name(section, level), FileManager.get_current_profile())
		if save != null and save.is_completed():
			count += 1
	return count

func count_section_ongoing_solutions(section: int) -> int:
	var level := 1
	var count := 0
	while FileManager.has_campaign_level(section, level):
		var save := FileManager.load_level(ExtraLevelLister.level_name(section, level))
		if save != null and not save.is_solution_empty():
			count += 1
		level += 1
	return count

func get_level_user_save(section : int, level : int):
	if not FileManager.has_extra_level_data(section, level):
		push_error("Not a valid extra level (section %s - level %s)" % [str(section), str(level)])
	return FileManager.load_level(ExtraLevelLister.level_name(section, level))

func get_level_data(section: int, level: int) -> LevelData:
	return FileManager.load_extra_level_data(section, level)

func level_stat(section: int, level: int) -> String:
	return "el%02d_%02d" % [section, level]