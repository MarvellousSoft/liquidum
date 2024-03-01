class_name GoogleStats
extends StatsTracker

func set_random_levels(_completed_count: Array[int]) -> void:
	pass

func set_endless_completed(_completed_count: Array[int]) -> void:
	pass

func set_streak(streak: int, best_streak: int) -> void:
	GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_current_daily_streak, float(streak))
	GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_max_daily_streak, float(best_streak))

func increment_daily_all() -> void:
	pass

func increment_daily_good() -> void:
	pass

func increment_insane_good() -> void:
	pass

func increment_workshop() -> void:
	pass

func unlock_daily_no_mistakes() -> void:
	pass

func update_campaign_stats() -> void:
	pass
