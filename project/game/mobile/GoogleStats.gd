class_name GoogleStats
extends StatsTracker

func set_random_levels(completed_count: Array[int]) -> void:
	var tot := 0
	var each := true
	for dif in RandomHub.Difficulty:
		var dif_val: int = RandomHub.Difficulty[dif]
		if completed_count[dif_val] < 5:
			each = false
		tot += completed_count[dif_val]
	if tot > 0:
		GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids.achievement_initiate_explorer)
	if each:
		GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids.achievement_expert_explorer)

func increment_random_any() -> void:
	GooglePlayGameServices.achievements_increment(GooglePlayGameServices.ids.achievement_intermediate_explorer, 1)

func set_endless_completed(_completed_count: Array[int]) -> void:
	pass

func set_streak(streak: int, best_streak: int) -> void:
	GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_current_daily_streak, float(streak))
	GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_max_daily_streak, float(best_streak))
	if streak >= 7:
		GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids.achievement_1_week_streak)

func increment_daily_all() -> void:
	pass

func increment_daily_good() -> void:
	pass

func increment_insane_good() -> void:
	GooglePlayGameServices.achievements_increment(GooglePlayGameServices.ids.achievement_ultimate_explorer, 1)

func increment_workshop() -> void:
	push_error("No workshop in mobile build")

func unlock_daily_no_mistakes() -> void:
	GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids.achievement_flawless_daily)

func update_campaign_stats() -> void:
	GooglePlayGameServices.achievements_load()
	var achs = await GooglePlayGameServices.achievements_loaded
	var id_to_cur_steps := {}
	for ach in achs:
		id_to_cur_steps[ach.achievementId] = ach.get("currentSteps", 0)

	var section := 1
	var total_completed := 0
	while CampaignLevelLister.has_section(section):
		var completed_levels := CampaignLevelLister.count_completed_section_levels(section)
		total_completed += completed_levels
		var section_levels := CampaignLevelLister.count_section_levels(section)
		if section > 1:
			GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids["achievement_section_%d_unlocked" % section])
		var completed: String = GooglePlayGameServices.ids["achievement_section_%d_completed" % section]
		if completed_levels > id_to_cur_steps[completed]:
			GooglePlayGameServices.achievements_increment(completed, completed_levels - id_to_cur_steps[completed])
		if section_levels - completed_levels > CampaignLevelLister.MAX_UNSOLVED_LEVELS:
			break
		section += 1
	while CampaignLevelLister.has_section(section):
		section += 1
	var completed: String = GooglePlayGameServices.ids.achievement_campaign_completed
	if total_completed > id_to_cur_steps[completed]:
		GooglePlayGameServices.achievements_increment(completed, total_completed - id_to_cur_steps[completed])
