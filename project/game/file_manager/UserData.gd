class_name UserData

const VERSION := 1

var random_levels_completed: int

enum { VERSION_KEY, RANDOM_LEVELS_COMPLETED }

func _init(random_levels_completed_: int) -> void:
	random_levels_completed = random_levels_completed_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		random_levels_completed = random_levels_completed,
	}

static func load_data(data_: Variant) -> UserData:
	if data_ == null:
		return UserData.new(0)
	var data: Dictionary = data_
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	return UserData.new(int(data.random_levels_completed))

