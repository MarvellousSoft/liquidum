class_name SteamStats

# Stats

# Achievements


static func flushNewAchievements() -> void:
	SteamManager.steam.storeStats()

static func set_random_levels(completed_count: Array[int]) -> void:
	var any := false
	var tot := 0
	var each := true
	for dif in RandomHub.Difficulty:
		var dif_val: int = RandomHub.Difficulty[dif]
		if completed_count[dif_val] == 0:
			each = false
		tot += completed_count[dif_val]
		var stat_name := "random_%s_levels" % [dif.to_lower()]
		SteamManager.steam.setStatInt(stat_name, completed_count[dif_val])
	if SteamStats._set_stat_with_goal("random_all_levels", tot, 25, "random_25", 5):
		any = true
	if tot > 0 and SteamStats._achieve("random_1", false):
		any = true
	if each and SteamStats._achieve("random_each", false):
		any = true
	if any:
		SteamStats.flushNewAchievements()

static func set_current_streak(streak: int) -> void:
	if SteamStats._set_stat_with_goal("daily_streak_current", streak, 7, "daily_streak_7", 2):
		SteamStats.flushNewAchievements()

static func _increment(stat: String) -> void:
	var val: int = SteamManager.steam.getStatInt(stat)
	SteamManager.steam.setStatInt(stat, val + 1)

static func increment_daily_all() -> void:
	SteamStats._increment("daily_all_levels")

static func increment_daily_good() -> void:
	SteamStats._increment("daily_good_levels")

static func increment_insane_good() -> void:
	const name := "random_insane_good_levels"
	var prev: int = SteamManager.steam.getStatInt(name)
	if SteamStats._set_stat_with_goal(name, prev + 1, 100, "random_100", 10):
		SteamStats.flushNewAchievements()

static func increment_workshop() -> void:
	var any := false
	var stat := "workshop_levels"
	if SteamStats._achieve("workshop_levels_1", false):
		any = true
	if SteamStats._set_stat_with_goal(stat, SteamManager.steam.getStatInt(stat) + 1, 5, "workshop_levels_5", 3):
		any = true
	if any:
		SteamStats.flushNewAchievements()

static func _achieve(achievement: String, flush := true) -> bool:
	if not SteamManager.steam.getAchievement(achievement).achieved:
		SteamManager.steam.setAchievement(achievement)
		if flush:
			SteamStats.flushNewAchievements()
		return true
	return false

static func unlock_daily_no_mistakes() -> void:
	SteamStats._achieve("daily_no_mistakes")

# Returns whether the goal was just reached
# Indicates progress every checkpoint values
static func _set_stat_with_goal(stat: String, val: int, goal: int, achievement: String, checkpoint: int) -> bool:
	var prev: int = SteamManager.steam.getStatInt(stat)
	if prev != val:
		SteamManager.steam.setStatInt(stat, val)
		if val > prev and val < goal and (prev / checkpoint) != (val / checkpoint):
			SteamManager.steam.indicateAchievementProgress(achievement, val, goal)
		return prev < goal and val >= goal
	return false

static func update_campaign_stats() -> void:
	var any := false
	var section := 1
	var total_completed := 0
	var total_levels := 0
	while LevelLister.has_section(section):
		var completed_levels := LevelLister.count_completed_section_levels(section)
		total_completed += completed_levels
		var section_levels := LevelLister.count_section_levels(section)
		total_levels += section_levels
		if section > 1:
			if SteamStats._achieve("section_%d_unlocked" % section, false):
				any = true
		if SteamStats._set_stat_with_goal("section_%d_levels" % section, completed_levels, section_levels, "section_%d_completed" % section, section_levels / 2):
			any = true
		if section_levels - completed_levels > LevelLister.MAX_UNSOLVED_LEVELS:
			break
		section += 1
	while LevelLister.has_section(section):
		total_levels += LevelLister.count_section_levels(section)
		section += 1
	if SteamStats._set_stat_with_goal("campaign_levels", total_completed, total_levels, "campaign_levels_completed", total_levels / 4):
		any = true
	if any:
		SteamStats.flushNewAchievements()
