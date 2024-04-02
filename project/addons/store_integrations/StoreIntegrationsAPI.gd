extends Node

var impls: Array[StoreIntegration] = []

enum SortMethod { SmallestFirst = 1, LargestFirst = 2 }

class LeaderboardMapping:
	var id: String
	var steam_id: String
	var google_id: String
	var ios_id: String
	func _init(id_: String, steam_id_: String, google_id_: String, ios_id_: String) -> void:
		id = id_
		steam_id = steam_id_
		google_id = google_id_
		ios_id = ios_id_

func _ready() -> void:
	if SteamIntegration.available():
		impls.append(SteamIntegration.new())
	if GoogleIntegration.available():
		impls.append(GoogleIntegration.new())
	if AppleIntegration.available():
		impls.append(await AppleIntegration.new())

func _process(dt: float) -> void:
	for impl in impls:
		impl.process(dt)

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
			))
		load_leaderboards_mapping(arr)

func leaderboard_create_if_not_exists(leaderboard_id: String, sort_method: SortMethod) -> void:
	for impl in impls:
		await impl.leaderboard_create_if_not_exists(leaderboard_id, sort_method)

func leaderboard_upload_score(leaderboard_id: String, score: float, keep_best := true, steam_details := PackedInt32Array()) -> void:
	for impl in impls:
		await impl.leaderboard_upload_score(leaderboard_id, score, keep_best, steam_details)

func leaderboard_show(leaderboard_id: String, google_timespan := 2, google_collection := 0) -> void:
	for impl in impls:
		await impl.leaderboard_show(leaderboard_id, google_timespan, google_collection)
