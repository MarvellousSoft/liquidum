class_name SteamStats

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

static func flushNewAchievements() -> void:
	Steam.storeStats()
