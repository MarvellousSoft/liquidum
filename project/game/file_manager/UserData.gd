class_name UserData

const VERSION := 1

var random_levels_completed: Array[int]

enum { VERSION_KEY, RANDOM_LEVELS_COMPLETED }

func _init(random_levels_completed_: Array[int]) -> void:
	random_levels_completed = random_levels_completed_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		random_levels_completed = random_levels_completed,
	}

static func load_data(data_: Variant) -> UserData:
	var completed: Array[int] = []
	if data_ == null:
		for i in RandomHub.Difficulty.size():
			completed.append(0)
		return UserData.new(completed)
	var data: Dictionary = data_
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	completed.assign(data.random_levels_completed)
	return UserData.new(completed)

