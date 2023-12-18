class_name SteamStats

# Stats

# Achievements


static func flushNewAchievements() -> void:
	Steam.storeStats()

static func set_random_levels(completed_count: Array[int]) -> void:
	var new_achievement := false
	var tot := 0
	if Steam.getStatInt("random_insane_levels") < 25 and completed_count[RandomHub.Difficulty.Insane] >= 25:
		new_achievement = true
	for dif in RandomHub.Difficulty:
		var dif_val: int = RandomHub.Difficulty[dif]
		tot += completed_count[dif_val]
		Steam.setStatInt("random_%s_levels" % [dif.to_lower()], completed_count[dif_val])
	if not Steam.getAchievement("random_25").achieved and tot >= 25:
		new_achievement = true
	Steam.setStatInt("random_all_levels", tot)
	if new_achievement:
		SteamStats.flushNewAchievements()

static func set_current_streak(streak: int) -> void:
	var had_streak := Steam.getAchievement("daily_streak_7")
	Steam.setStatInt("daily_streak_current", streak)
	if not had_streak and streak >= 7:
		SteamStats.flushNewAchievements()

static func _increment(stat: String) -> void:
	var val := Steam.getStatInt(stat)
	Steam.setStatInt(stat, val + 1)

static func increment_daily_all() -> void:
	SteamStats._increment("daily_all_levels")

static func increment_daily_good() -> void:
	SteamStats._increment("daily_good_levels")

static func increment_workshop() -> void:
	SteamStats._increment("workshop_levels")

static func _achieve(achievement: String, flush := true) -> bool:
	if not Steam.getAchievement(achievement).achieved:
		Steam.setAchievement(achievement)
		SteamStats.flushNewAchievements()
		return true
	return false

static func unlock_daily_no_mistakes() -> void:
	SteamStats._achieve("daily_no_mistakes")

static func _section_unlocked(section: int) -> String:
	return "section_%d_unlocked" % section

static func update_campaign_stats() -> void:
	var any := false
	var section := 1
	while LevelLister.has_section(section):
		var completed_levels := LevelLister.count_completed_section_levels(section)
		var total_levels := LevelLister.count_section_levels(section)
		# TODO: Other achievements
		if section > 1:
			if SteamStats._achieve("section_%d_unlocked" % section, false):
				any = true
		if completed_levels > LevelLister.MAX_UNSOLVED_LEVELS:
			break
		section += 1
	if any:
		SteamStats.flushNewAchievements()
