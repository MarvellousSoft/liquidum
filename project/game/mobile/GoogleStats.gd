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
	
const STREAK_ACH: Array[int] = [7, 4]

func set_recurring_streak(type: RecurringMarathon.Type, streak: int, best_streak: int) -> void:
	var type_name := RecurringMarathon.type_name(type)
	GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids["leaderboard_current_%s_streak" % type_name], float(streak))
	GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids["leaderboard_max_%s_streak" % type_name], float(best_streak))
	var ach := STREAK_ACH[type]
	if streak >= ach:
		GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids["achievement_%d_%s_streak" % [ach, type_name]])

func increment_recurring_all(_type: RecurringMarathon.Type) -> void:
	pass

func increment_recurring_good(_type: RecurringMarathon.Type) -> void:
	pass

func increment_recurring_started(_type: RecurringMarathon.Type) -> void:
	pass

func increment_insane_good() -> void:
	GooglePlayGameServices.achievements_increment(GooglePlayGameServices.ids.achievement_ultimate_explorer, 1)

func increment_endless_good() -> void:
	GooglePlayGameServices.achievements_increment(GooglePlayGameServices.ids.achievement_100__levels, 1)

func increment_workshop() -> void:
	push_error("No workshop in mobile build")

func unlock_recurring_no_mistakes(type: RecurringMarathon.Type) -> void:
	GooglePlayGameServices.achievements_unlock(GooglePlayGameServices.ids["achievement_flawless_%s" % RecurringMarathon.type_name(type)])

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
		if id_to_cur_steps.has(completed) and completed_levels > id_to_cur_steps[completed]:
			GooglePlayGameServices.achievements_increment(completed, completed_levels - id_to_cur_steps[completed])
		if section_levels - completed_levels > CampaignLevelLister.MAX_UNSOLVED_LEVELS:
			break
		section += 1
	while CampaignLevelLister.has_section(section):
		section += 1
	var completed: String = GooglePlayGameServices.ids.achievement_campaign_completed
	if id_to_cur_steps.has(completed) and total_completed > id_to_cur_steps[completed]:
		GooglePlayGameServices.achievements_increment(completed, total_completed - id_to_cur_steps[completed])
	const ACH_NAMES := {
		1: "achievement_done__solved",
		2: "achievement_reflected",
	}
	var extra_section := 1
	while ExtraLevelLister.has_section(extra_section):
		var completed_levels := ExtraLevelLister.count_completed_section_levels(extra_section)
		if ACH_NAMES.has(extra_section):
			completed = GooglePlayGameServices.ids[ACH_NAMES[extra_section]]
			if ExtraLevelLister.is_free(extra_section):
				if id_to_cur_steps.has(completed) and completed_levels > id_to_cur_steps[completed]:
					GooglePlayGameServices.achievements_increment(completed, completed_levels - id_to_cur_steps[completed])
			else:
				pass
		extra_section += 1
