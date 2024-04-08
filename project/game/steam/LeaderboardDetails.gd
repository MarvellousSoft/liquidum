# What to put in Steam leaderboards details
class_name LeaderboardDetails

# Versioning so we can more easily change this stuff later. MAX 256
const VERSION := 2

var flair: SteamFlair

func _init(flair_: SteamFlair) -> void:
	flair = flair_

static func to_arr(details: LeaderboardDetails) -> PackedInt32Array:
	if details == null:
		return PackedInt32Array()
	var arr := PackedByteArray()
	arr.append(VERSION)
	arr.append_array(SteamFlair.encode(details.flair))
	while arr.size() % 4 != 0:
		arr.append(0)
	return arr.to_int32_array()

static func from_arr(arr_32: PackedInt32Array) -> LeaderboardDetails:
	if arr_32.is_empty():
		return LeaderboardDetails.new(null)
	var arr := arr_32.to_byte_array()
	var version := arr[0]
	# No version, basically
	if version < 1:
		return LeaderboardDetails.new(null)
	if version < 2:
		version = 2
		var old_text := SteamFlair.old_flair_decode_text(1, arr)
		var id := -1
		if old_text == "pro":
			id = FlairManager.FlairId.ProStart + 2
		elif old_text != "":
			id = FlairManager.FlairId.Dev
		arr.resize(5)
		arr.encode_s32(1, id)
	if version < VERSION:
		push_error("Incompatible version of leaderboard details, let's hope for the best.")
	var flair_ := SteamFlair.decode(1, arr)
	return LeaderboardDetails.new(flair_)
