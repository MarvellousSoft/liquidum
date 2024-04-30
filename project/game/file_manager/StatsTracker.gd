class_name StatsTracker
extends Node

static var base := StatsTracker.new()
static var steam := SteamStats.new()
static var google := GoogleStats.new()

static func instance() -> StatsTracker:
	if SteamManager.enabled and SteamManager.stats_received:
		return MultiplexerStats.new([steam, base])
	elif GooglePlayGameServices.enabled:
		return MultiplexerStats.new([google, base])
	elif AppleIntegration.available():
		# StoreIntegrations calls do the right thing
		return base
	return base

func set_random_levels(completed_count: Array[int]) -> void:
	var tot := 0
	var each := true
	for dif in RandomHub.Difficulty:
		var dif_val: int = RandomHub.Difficulty[dif]
		if completed_count[dif_val] < 5:
			each = false
		tot += completed_count[dif_val]
	await StoreIntegrations.achievement_set("random_25", tot, 25)
	if tot > 0:
		await StoreIntegrations.achievement_set("random_1")
	if each:
		await StoreIntegrations.achievement_set("random_each")

func set_endless_completed(completed_count: Array[int]) -> void:
	var total := 0
	for i in completed_count.size():
		total += completed_count[i]
	if total >= 1:
		await StoreIntegrations.achievement_set("endless_1")
	await StoreIntegrations.achievement_set("endless_10", total, 10)

func set_endless_good(count: int) -> void:
	await StoreIntegrations.achievement_set("endless_100", count, 100)

const STREAK_ACH: Array[int] = [7, 4]

func set_recurring_streak(type: RecurringMarathon.Type, streak: int, best_streak: int) -> void:
	var type_name := RecurringMarathon.type_name(type)
	await StoreIntegrations.leaderboard_upload_score("%s_current_streak" % type_name, float(streak), false)
	await StoreIntegrations.leaderboard_upload_score("%s_max_streak" % type_name, float(best_streak), true)
	var ach := STREAK_ACH[type]
	if streak >= ach:
		await StoreIntegrations.achievement_set("%s_streak_%d" % [type_name, ach])

func increment_recurring_all(_type: RecurringMarathon.Type) -> void:
	pass

func increment_recurring_good(_type: RecurringMarathon.Type) -> void:
	pass

func increment_recurring_started(_type: RecurringMarathon.Type) -> void:
	pass

func increment_insane_good() -> void:
	var new_val := UserData.current().bump_insane_good()
	await StoreIntegrations.achievement_set("random_100", new_val, 100)

func increment_random_any() -> void:
	pass

func increment_workshop() -> void:
	pass

func unlock_recurring_no_mistakes(type: RecurringMarathon.Type) -> void:
	await StoreIntegrations.achievement_set("%s_no_mistakes" % RecurringMarathon.type_name(type))

func update_campaign_stats() -> void:
	var section := 1
	var total_completed := 0
	while CampaignLevelLister.has_section(section):
		var completed_levels := CampaignLevelLister.count_completed_section_levels(section)
		total_completed += completed_levels
		var section_levels := CampaignLevelLister.count_section_levels(section)
		if section > 1:
			await StoreIntegrations.achievement_set("section_%d_unlocked" % [section])
		await StoreIntegrations.achievement_set("section_%d_completed" % [section], completed_levels, section_levels)
		if section_levels - completed_levels > CampaignLevelLister.MAX_UNSOLVED_LEVELS:
			break
		section += 1
	while CampaignLevelLister.has_section(section):
		section += 1
	await StoreIntegrations.achievement_set("campaign_levels_completed", total_completed, 48)
	var extra_section := 1
	while ExtraLevelLister.has_section(extra_section):
		var completed_levels := ExtraLevelLister.count_completed_section_levels(extra_section)
		var section_levels := ExtraLevelLister.count_section_levels(extra_section)
		if ExtraLevelLister.is_free(extra_section):
			await StoreIntegrations.achievement_set("extra_%02d_complete" % [extra_section], completed_levels, section_levels)
		else:
			pass
		extra_section += 1

func unlock_flawless_marathon(dif: RandomHub.Difficulty) -> void:
	await StoreIntegrations.achievement_set("marathon_%s_10_no_mistakes" % RandomHub.Difficulty.find_key(dif).to_lower())

func unlock_fast_marathon(dif: RandomHub.Difficulty) -> void:
	await StoreIntegrations.achievement_set("marathon_%s_10_speedrun" % RandomHub.Difficulty.find_key(dif).to_lower())
