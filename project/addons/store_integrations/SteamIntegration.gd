class_name SteamIntegration extends StoreIntegration

static func available() -> bool:
	return Engine.has_singleton(&"Steam")

var steam = null
var ld_id_to_steam_name := {}
var ld_steam_name_to_id := {}

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		if ld.steam_id != "":
			ld_id_to_steam_name[ld.id] = ld.steam_id

func _init() -> void:
	steam = Engine.get_singleton(&"Steam")

func _store_ld_find_result(steam_name: String) -> void:
	var ret: Array = await steam.leaderboard_find_result
	if not ret[1]:
		push_warning("Leaderboard not found: %s" % [steam_name])
	else:
		ld_steam_name_to_id[steam_name] = ret[0]

func leaderboard_create_if_not_exists(leaderboard_id: String, sort_method: StoreIntegrations.SortMethod) -> void:
	if not ld_id_to_steam_name.has(leaderboard_id):
		ld_id_to_steam_name[leaderboard_id] = leaderboard_id
	var steam_name: String = ld_id_to_steam_name[leaderboard_id]
	if not ld_steam_name_to_id.has(steam_name):
		steam.findOrCreateLeaderboard(steam_name, sort_method, 1)
		await _store_ld_find_result(steam_name)

func _get_ld_id(leaderboard_id: String) -> int:
	var steam_name: String = ld_id_to_steam_name.get(leaderboard_id, leaderboard_id)
	if not ld_steam_name_to_id.has(steam_name):
		steam.findLeaderboard(steam_name)
		await _store_ld_find_result(steam_name)
	return ld_steam_name_to_id.get(steam_name, -1)

func leaderboard_upload_score(leaderboard_id: String, score: float, keep_best: bool, steam_details: PackedInt32Array) -> void:
	var id := await _get_ld_id(leaderboard_id)
	if id <= 0:
		return
	steam.uploadLeaderboardScore(int(score), keep_best, steam_details, id)
	var ret: Array = await steam.leaderboard_score_uploaded
	if not ret[0]:
		push_warning("Failed to upload leaderboard entry for %d (%s)" % [id, leaderboard_id])
	else:
		print("Did upload to leaderboard %d" % [id])
