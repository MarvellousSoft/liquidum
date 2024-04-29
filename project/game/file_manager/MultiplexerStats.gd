class_name MultiplexerStats
extends StatsTracker

var impls: Array[StatsTracker] = []

func _init(impls_: Array[StatsTracker]) -> void:
	impls = impls_

func set_random_levels(completed_count: Array[int]) -> void:
	for impl in impls:
		await impl.set_random_levels(completed_count)

func set_endless_completed(completed_count: Array[int]) -> void:
	for impl in impls:
		await impl.set_endless_completed(completed_count)

func set_endless_good(count: int) -> void:
	for impl in impls:
		await impl.set_endless_good(count)


func set_recurring_streak(type: RecurringMarathon.Type, streak: int, best_streak: int) -> void:
	for impl in impls:
		await impl.set_recurring_streak(type, streak, best_streak)

func increment_recurring_all(type: RecurringMarathon.Type) -> void:
	for impl in impls:
		impl.increment_recurring_all(type)

func increment_recurring_good(type: RecurringMarathon.Type) -> void:
	for impl in impls:
		impl.increment_recurring_good(type)

func increment_recurring_started(type: RecurringMarathon.Type) -> void:
	for impl in impls:
		impl.increment_recurring_started(type)

func increment_insane_good() -> void:
	for impl in impls:
		await impl.increment_insane_good()

func increment_random_any() -> void:
	for impl in impls:
		impl.increment_random_any()

func increment_workshop() -> void:
	for impl in impls:
		impl.increment_workshop()

func unlock_recurring_no_mistakes(type: RecurringMarathon.Type) -> void:
	for impl in impls:
		await impl.unlock_recurring_no_mistakes(type)

func update_campaign_stats() -> void:
	for impl in impls:
		await impl.update_campaign_stats()

func unlock_flawless_marathon(dif: RandomHub.Difficulty) -> void:
	for impl in impls:
		await impl.unlock_flawless_marathon(dif)

func unlock_fast_marathon(dif: RandomHub.Difficulty) -> void:
	for impl in impls:
		await impl.unlock_fast_marathon(dif)
