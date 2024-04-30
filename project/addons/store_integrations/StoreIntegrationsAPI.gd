extends Node

var impls: Array[StoreIntegration] = []
var apple: AppleIntegration = null
var playfab: PlayFabIntegration = null

enum SortMethod { SmallestFirst = 1, LargestFirst = 2 }

class LeaderboardEntry:
	var rank: int
	var display_name: String
	var mistakes: int
	var secs: int
	var extra_data: Dictionary

class LeaderboardData:
	var has_self: bool = false
	var entries: Array[LeaderboardEntry] = []

class LeaderboardMapping:
	var id: String
	var steam_id: String
	var google_id: String
	var apple_id: String
	var playfab_id: String
	var sort_method: SortMethod
	func _init(id_: String, steam_id_: String, google_id_: String, apple_id_: String, playfab_id_: String, sort_method_: SortMethod) -> void:
		id = id_
		steam_id = steam_id_
		google_id = google_id_
		apple_id = apple_id_
		playfab_id = playfab_id_
		sort_method = sort_method_

func _ready() -> void:
	impls.append(LogIntegration.new())
	if SteamIntegration.available():
		impls.append(SteamIntegration.new())
	if GoogleIntegration.available():
		impls.append(GoogleIntegration.new())
	if AppleIntegration.available():
		apple = AppleIntegration.new()
		impls.append(apple)
	if PlayFabIntegration.available():
		playfab = PlayFabIntegration.new()
		impls.append(playfab)
	
	for impl in impls:
		add_child(impl)

func authenticated() -> bool:
	for impl in impls:
		if impl.authenticated():
			return true
	return false

func load_leaderboards_mapping(lds: Array[LeaderboardMapping]) -> void:
	for impl in impls:
		impl.add_leaderboard_mappings(lds)

# Format:
# {
#     "leaderboard_id": {
#         "steam_id": "",
#         "google_id": "",
#         "apple_id": "",
#         "playfab_id": "",
#     }
# }
func load_leaderboards_mapping_from_json(file_name: String) -> void:
	var file := FileAccess.open(file_name, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != Error.OK:
		push_error("Error parsing JSON on line %d: %s" % [json.get_error_line(), json.get_error_message()])
	else:
		var data: Dictionary = json.get_data()
		var arr: Array[LeaderboardMapping] = []
		for id in data.keys():
			arr.append(LeaderboardMapping.new(
				id,
				data[id].get("steam_id", ""),
				data[id].get("google_id", ""),
				data[id].get("apple_id", ""),
				data[id].get("playfab_id", ""),
				SortMethod.get(data[id].get("sort_method", ""), SortMethod.LargestFirst),
			))
		load_leaderboards_mapping(arr)

func leaderboard_create_if_not_exists(leaderboard_id: String, sort_method: SortMethod) -> void:
	for impl in impls:
		await impl.leaderboard_create_if_not_exists(leaderboard_id, sort_method)

func leaderboard_upload_score(leaderboard_id: String, score: float, keep_best := true, steam_details := PackedInt32Array()) -> void:
	for impl in impls:
		await impl.leaderboard_upload_score(leaderboard_id, score, keep_best, steam_details)

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> void:
	for impl in impls:
		await impl.leaderboard_upload_completion(leaderboard_id, time_secs, mistakes, keep_best, steam_details)

func leaderboard_show(leaderboard_id: String, google_timespan := 2, google_collection := 0) -> void:
	for impl in impls:
		await impl.leaderboard_show(leaderboard_id, google_timespan, google_collection)

func achievement_set(ach_id: String, steps: int = 1, total_steps: int = 1) -> void:
	for impl in impls:
		await impl.achievement_set(ach_id, clampi(steps, 0, total_steps), total_steps)

func achievement_show_all() -> void:
	for impl in impls:
		await impl.achievement_show_all()

func leaderboard_download_completion(leaderboard_id: String, start: int = 1, count: int = 100) -> StoreIntegrations.LeaderboardData:
	for impl in impls:
		var data := await impl.leaderboard_download_completion(leaderboard_id, start, count)
		if data != null:
			return data
	return StoreIntegrations.LeaderboardData.new()
