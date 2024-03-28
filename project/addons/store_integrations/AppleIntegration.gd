class_name AppleIntegration extends StoreIntegration

signal event(data: Dictionary)

static func available() -> bool:
	return Engine.has_singleton("GameCenter")

var apple = null
var ld_id_to_apple_id := {}
var _authenticated := false

func _init() -> void:
	apple = Engine.get_singleton("GameCenter")
	apple.authenticate()
	var resp = await event
	_authenticated = resp.result == "ok"

func authenticated() -> bool:
	return _authenticated

func process(_dt: float) -> void:
	while apple.get_pending_event_count() > 0:
		var new_event: Dictionary = apple.pop_pending_event()
		print("Apple event: %s" % [new_event])
		event.emit(new_event)

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		ld_id_to_apple_id[ld.leaderboard_id] = ld.apple_id

func leaderboard_upload_score(leaderboard_id: String, score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> void:
	if ld_id_to_apple_id.has(leaderboard_id):
		apple.post_score({
			score = score,
			category = ld_id_to_apple_id[leaderboard_id],
		})
		await event

func leaderboard_show(leaderboard_id: String, _google_timespan: int, _google_collection: int) -> void:
	if ld_id_to_apple_id.has(leaderboard_id):
		apple.show_game_center({"view": "leaderboards", "leaderboard_name": ld_id_to_apple_id[leaderboard_id]})
	else:
		apple.show_game_center({})
	await event
