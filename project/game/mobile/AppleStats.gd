class_name AppleStats
extends StatsTracker


func set_random_levels(_completed_count: Array[int]) -> void:
	pass

func set_endless_completed(_completed_count: Array[int]) -> void:
	pass

func set_endless_good(_count: int) -> void:
	pass

func set_recurring_streak(_type: RecurringMarathon.Type, _streak: int, _best_streak: int) -> void:
	pass

func increment_recurring_all(_type: RecurringMarathon.Type) -> void:
	pass

func increment_recurring_good(_type: RecurringMarathon.Type) -> void:
	pass

func increment_recurring_started(_type: RecurringMarathon.Type) -> void:
	pass

func increment_insane_good() -> void:
	pass

func increment_random_any() -> void:
	pass

func increment_workshop() -> void:
	pass

func unlock_recurring_no_mistakes(_type: RecurringMarathon.Type) -> void:
	pass

func update_campaign_stats() -> void:
	pass

func unlock_flawless_marathon(_dif: RandomHub.Difficulty) -> void:
	pass

func unlock_fast_marathon(_dif: RandomHub.Difficulty) -> void:
	pass
