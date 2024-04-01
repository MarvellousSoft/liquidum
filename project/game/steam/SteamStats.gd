class_name SteamStats
extends StatsTracker

# Stats

# Achievements


func flushNewAchievements() -> void:
	SteamManager.steam.storeStats()

func set_random_levels(completed_count: Array[int]) -> void:
	var any := false
	var tot := 0
	var each := true
	for dif in RandomHub.Difficulty:
		var dif_val: int = RandomHub.Difficulty[dif]
		if completed_count[dif_val] < 5:
			each = false
		tot += completed_count[dif_val]
		var stat_name := "random_%s_levels" % [dif.to_lower()]
		SteamManager.steam.setStatInt(stat_name, completed_count[dif_val])
	if _set_stat_with_goal("random_all_levels", tot, 25, "random_25", 5):
		any = true
	if tot > 0 and _achieve("random_1", false):
		any = true
	if each and _achieve("random_each", false):
		any = true
	if any:
		flushNewAchievements()

func set_endless_completed(completed_count: Array[int]) -> void:
	var any := false
	var total := 0
	for i in completed_count.size():
		var stat_name := "endless_%02d_levels" % [i + 1]
		SteamManager.steam.setStatInt(stat_name, completed_count[i])
		total += completed_count[i]
	if total >= 1 and _achieve("endless_1", false):
		any = true
	if _set_stat_with_goal("endless_levels", total, 10, "endless_10", 5):
		any = true
	if any:
		flushNewAchievements()


func _find_leaderboard(l_name: String) -> int:
	await SteamManager.ld_mutex.lock()
	SteamManager.steam.findLeaderboard(l_name)
	var ret: Array = await SteamManager.steam.leaderboard_find_result
	SteamManager.ld_mutex.unock()
	if not ret[1]:
		push_warning("Leaderboard %s not found" % l_name)
		return -1
	else:
		return ret[0]

const STREAK_ACH: Array[int] = [7, 4]

func set_recurring_streak(type: RecurringMarathon.Type, streak: int, best_streak: int) -> void:
	var type_name := RecurringMarathon.type_name(type)
	var CUR := "%s_streak_current" % type_name
	var MAX := "%s_streak_max" % type_name
	var upload_current: bool = (streak != SteamManager.steam.getStatInt(CUR))
	var upload_max: bool = (streak > SteamManager.steam.getStatInt(MAX))
	if type == RecurringMarathon.Type.Weekly and streak < 4 and best_streak < 4:
		if SteamManager.steam.getAchievement("weekly_streak_4").achieved:
			SteamManager.steam.clearAchievement("weekly_streak_4")
			flushNewAchievements()
	if _set_stat_with_goal(CUR, streak, STREAK_ACH[type], "%s_streak_%d" % [type_name, STREAK_ACH[type]], 2):
		flushNewAchievements()
	await SteamManager.ld_mutex.lock()
	if upload_current:
		SteamManager.steam.setStatInt(CUR, streak)
		await StoreIntegrations.leaderboard_upload_score("%s_current_streak" % [type_name], float(streak), false)
	if upload_max:
		SteamManager.steam.setStatInt(MAX, streak)
		await StoreIntegrations.leaderboard_upload_score("%s_max_streak" % [type_name], float(streak), true)
	SteamManager.ld_mutex.unlock()

func _increment(stat: String) -> void:
	var val: int = SteamManager.steam.getStatInt(stat)
	SteamManager.steam.setStatInt(stat, val + 1)

func increment_recurring_all(type: RecurringMarathon.Type) -> void:
	_increment("%s_all_levels" % RecurringMarathon.type_name(type))

func increment_recurring_good(type: RecurringMarathon.Type) -> void:
	_increment("%s_good_levels" % RecurringMarathon.type_name(type))

func increment_recurring_started(type: RecurringMarathon.Type) -> void:
	_increment("%s_started" % RecurringMarathon.type_name(type))

func set_endless_good(count: int) -> void:
	var l_name := "endless_good_levels"
	if _set_stat_with_goal(l_name, count, 100, "endless_100", 10):
		flushNewAchievements()

func increment_insane_good() -> void:
	const l_name := "random_insane_good_levels"
	var prev: int = SteamManager.steam.getStatInt(l_name)
	if _set_stat_with_goal(l_name, prev + 1, 100, "random_100", 10):
		flushNewAchievements()

func increment_workshop() -> void:
	var any := false
	var stat := "workshop_levels"
	if _achieve("workshop_levels_1", false):
		any = true
	if _set_stat_with_goal(stat, SteamManager.steam.getStatInt(stat) + 1, 5, "workshop_levels_5", 3):
		any = true
	if any:
		flushNewAchievements()

func _achieve(achievement: String, flush := true) -> bool:
	if not SteamManager.steam.getAchievement(achievement).achieved:
		SteamManager.steam.setAchievement(achievement)
		if flush:
			flushNewAchievements()
		return true
	return false

func unlock_recurring_no_mistakes(type: RecurringMarathon.Type) -> void:
	_achieve("%s_no_mistakes" % RecurringMarathon.type_name(type))

# Returns whether the goal was just reached
# Indicates progress every checkpoint values
func _set_stat_with_goal(stat: String, val: int, goal: int, achievement: String, checkpoint: int) -> bool:
	var prev: int = SteamManager.steam.getStatInt(stat)
	if prev != val:
		SteamManager.steam.setStatInt(stat, val)
		if val > prev and val < goal and (prev / checkpoint) != (val / checkpoint):
			SteamManager.steam.indicateAchievementProgress(achievement, val, goal)
		return prev < goal and val >= goal
	return false

func update_campaign_stats() -> void:
	var any := false
	var section := 1
	var total_completed := 0
	var total_levels := 0
	while CampaignLevelLister.has_section(section):
		var completed_levels := CampaignLevelLister.count_completed_section_levels(section)
		total_completed += completed_levels
		var section_levels := CampaignLevelLister.count_section_levels(section)
		total_levels += section_levels
		if section > 1:
			if _achieve("section_%d_unlocked" % section, false):
				any = true
		if _set_stat_with_goal("section_%d_levels" % section, completed_levels, section_levels, "section_%d_completed" % section, section_levels / 2):
			any = true
		if section_levels - completed_levels > CampaignLevelLister.MAX_UNSOLVED_LEVELS:
			break
		section += 1
	while CampaignLevelLister.has_section(section):
		total_levels += CampaignLevelLister.count_section_levels(section)
		section += 1
	if _set_stat_with_goal("campaign_levels", total_completed, total_levels, "campaign_levels_completed", total_levels / 4):
		any = true
	var extra_section := 1
	while ExtraLevelLister.has_section(extra_section):
		var completed := ExtraLevelLister.count_completed_section_levels(extra_section)
		var section_levels := ExtraLevelLister.count_section_levels(extra_section)
		var s_name := "extra_%02d_levels" % [extra_section]
		if ExtraLevelLister.is_free(extra_section):
			if _set_stat_with_goal(s_name, completed, section_levels, "extra_%02d_complete", section_levels / 2):
				any = true
		else:
			SteamManager.steam.setStatInt(s_name, completed)
		extra_section += 1
	if any:
		flushNewAchievements()

func unlock_flawless_marathon(dif: RandomHub.Difficulty) -> void:
	_achieve("marathon_%s_10_no_mistakes" % RandomHub.Difficulty.find_key(dif).to_lower())

func unlock_fast_marathon(dif: RandomHub.Difficulty) -> void:
	_achieve("marathon_%s_10_speedrun" % RandomHub.Difficulty.find_key(dif).to_lower())
