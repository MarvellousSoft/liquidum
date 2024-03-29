class_name StoreIntegration

static func available() -> bool:
    return false

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
    pass

func leaderboard_create_if_not_exists(_leaderboard_id: String, _sort_method: StoreIntegrations.SortMethod) -> void:
    await null

func leaderboard_upload_score(_leaderboard_id: String, _score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> void:
    await null

func leaderboard_show(_leaderboard_id: String, _google_timespan: int, _google_collection: int) -> void:
    pass