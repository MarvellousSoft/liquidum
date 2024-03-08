# What to put in Steam leaderboards details
class_name LeaderboardDetails

# Versioning so we can more easily change this stuff later
const VERSION := 1

var flair: Flair

func _init(flair_: Flair) -> void:
	flair = flair_

func to_arr() -> PackedInt32Array:
	var arr := PackedInt32Array()
	if flair != null:
		flair.write_to_arr(arr)
	arr.append(VERSION)
	return arr

static func from_arr(arr: PackedInt32Array) -> LeaderboardDetails:
	if arr.is_empty():
		return LeaderboardDetails.new(null)
	var version := arr[-1]
	arr.remove_at(-1)
	# Example version migration
	#if version < 2:
	#	version = 2
	#	# Migrate to version 2
	if version < VERSION:
		push_error("Incompatible version of leaderboard details, let's hope for the best.")
	var flair := Flair.from_arr(arr)
	return LeaderboardDetails.new(flair)
