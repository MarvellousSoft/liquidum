class_name StatsTracker
extends Node

static var empty := StatsTracker.new()
static var steam := SteamStats.new()
static var google := GoogleStats.new()


static func instance() -> StatsTracker:
	if SteamManager.enabled and SteamManager.stats_received:
		return steam
	elif GooglePlayGameServices.enabled:
		return google
	return empty

func set_random_levels(_completed_count: Array[int]) -> void:
	pass

func set_endless_completed(_completed_count: Array[int]) -> void:
	pass

func set_streak(_streak: int, _best_streak: int) -> void:
	pass

func increment_daily_all() -> void:
	pass

func increment_daily_good() -> void:
	pass

func increment_insane_good() -> void:
	pass

func increment_random_any() -> void:
	pass

func increment_workshop() -> void:
	pass

func unlock_daily_no_mistakes() -> void:
	pass

func update_campaign_stats() -> void:
	pass
