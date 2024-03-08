# What to put in Steam leaderboards details
class_name LeaderboardDetails

# Versioning so we can more easily change this stuff later. MAX 256
const VERSION := 1

var flair: Flair

func _init(flair_: Flair) -> void:
	flair = flair_

func to_arr() -> PackedInt32Array:
	var arr := PackedByteArray()
	arr.append(VERSION)
	arr.append_array(Flair.encode(flair))
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
	# Example version migration
	#if version < 2:
	#	version = 2
	#	# Migrate to version 2
	if version < VERSION:
		push_error("Incompatible version of leaderboard details, let's hope for the best.")
	var flair_ := Flair.decode(1, arr)
	# For more stuff, we need to know the offset of the Flair
	return LeaderboardDetails.new(flair_)
