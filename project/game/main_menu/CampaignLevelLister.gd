extends LevelLister

const INITIAL_UNLOCKED_LEVELS := 3
const MAX_UNSOLVED_LEVELS := 2

func level_name(section: int, level: int) -> String:
	return "level%02d_%02d" % [section, level]

func has_section(section: int) -> int:
	return FileManager.has_campaign_level(section, 1)

func get_levels_in_section(section: int) -> int:
	var i := 1
	while FileManager.has_campaign_level(section, i):
		i += 1
	return i - 1


func just_unlocked_level() -> Dictionary:
	var level_info = {
		"level_number": -1,
		"section": -1,
	}
	
	return level_info


func get_max_unlocked_levels(_section: int) -> int:
	return MAX_UNSOLVED_LEVELS


func get_initial_unlocked_levels() -> int:
	return INITIAL_UNLOCKED_LEVELS


func get_level_user_save(section : int, level : int):
	if not FileManager.has_campaign_level(section, level):
		push_error("Not a valid level (section %s - level %s)" % [str(section), str(level)])
	return FileManager.load_level(CampaignLevelLister.level_name(section, level))


func count_all_game_sections() -> int:
	for i in range(1, 100):
		if not has_section(i):
			return i - 1
	return -1


func section_complete(section: int) -> bool:
	var count_uncompleted := 0
	for i in range(1, 100):
		if not FileManager.has_campaign_level(section, i) or count_uncompleted > MAX_UNSOLVED_LEVELS:
			if i == 1:
				# No levels in section
				return false
			break
		var save := FileManager.load_level(CampaignLevelLister.level_name(section, i))
		if save == null or not save.is_completed():
			count_uncompleted += 1
	return count_uncompleted <= MAX_UNSOLVED_LEVELS

# Levels 1-return are unlocked in this section. If 0, none is unlocked.
func get_max_unlocked_level(section: int) -> int:
	if section > 1:
		if not CampaignLevelLister.section_complete(section - 1):
			return 0
	var count_completed := 0
	var i := 1
	var initial_unlock = INITIAL_UNLOCKED_LEVELS if section > 1 else 1
	while FileManager.has_campaign_level(section, i) and i <= initial_unlock + count_completed:
		var save := FileManager.load_level(CampaignLevelLister.level_name(section, i))
		if save != null and save.is_completed():
			count_completed += 1
		i += 1
	return i - 1


func count_section_levels(section : int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_campaign_level(section, level):
			break
		count += 1
	return count


func count_completed_section_levels(section : int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_campaign_level(section, level):
			break
		var save := FileManager.load_level(CampaignLevelLister.level_name(section, level), FileManager.get_current_profile())
		if save != null and save.is_completed():
			count += 1
	return count


func count_completed_levels(profile_name: String) -> int:
	var count := 0
	for section in range(1, 50):
		if not FileManager.has_campaign_level(section, 1):
			break
		for level in range(1, 50):
			if not FileManager.has_campaign_level(section, level):
				break
			var save := FileManager.load_level(CampaignLevelLister.level_name(section, level), profile_name)
			if save != null and save.is_completed():
				count += 1
	return count


func clear_all_level_saves(profile_name: String) -> void:
	for section in range(1, 50):
		if not FileManager.has_campaign_level(section, 1):
			break
		for level in range(1, 50):
			if not FileManager.has_campaign_level(section, level):
				break
			FileManager.clear_level(CampaignLevelLister.level_name(section, level), profile_name)


func count_section_ongoing_solutions(section: int) -> int:
	var count := 0
	for level in range(1, 50):
		if not FileManager.has_campaign_level(section, level):
			break
		var save := FileManager.load_level(CampaignLevelLister.level_name(section, level))
		if save != null and not save.is_solution_empty():
			count += 1
	return count


func all_campaign_levels_completed() -> bool:
	# Let's go on reverse because it's more efficient
	var sections := count_all_game_sections()
	for section in range(sections, 0, -1):
		for level in range(1, 50):
			if not FileManager.has_campaign_level(section, level):
				break
			var save := FileManager.load_level(CampaignLevelLister.level_name(section, level))
			if save == null or not save.is_completed():
				return false
	return true

func get_level_data(section: int, level: int) -> LevelData:
	return FileManager.load_campaign_level_data(section, level)

func level_stat(section: int, level: int) -> String:
	return "l%02d_%02d" % [section, level]
