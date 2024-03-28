class_name GoogleIntegration extends StoreIntegration

static func available() -> bool:
	return Engine.has_singleton(&"GodotGooglePlayGameServices")

var google = null
var ld_id_to_google_id := {}

func _init() -> void:
	google = Engine.get_singleton(&"GodotGooglePlayGameServices")

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		if ld.google_id != "":
			ld_id_to_google_id[ld.id] = ld.google_id

func leaderboard_upload_score(leaderboard_id: String, score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> void:
	var id : String = ld_id_to_google_id.get(leaderboard_id, "")
	if not id.is_empty():
		google.leaderboardsSubmitScore(id, score)
		await google.leaderboardsScoreSubmitted

func leaderboard_show(leaderboard_id: String, timespan: int, collection: int) -> void:
	var id : String = ld_id_to_google_id.get(leaderboard_id, "")
	if not id.is_empty():
		google.leaderboardsShowForTimeSpanAndCollection(timespan, collection)