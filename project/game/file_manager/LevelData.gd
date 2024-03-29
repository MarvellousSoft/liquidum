class_name LevelData

const VERSION := 1

var full_name: String
var description: String
var grid_data: Dictionary
var tutorial: String
# Only used for levels created from the random hub. It's either RandomHub.Difficulty or -1
var difficulty: int = -1
var seed_str := ""
var manually_seeded := false
# If not -1, we're in the middle of a marathon
var marathon_left: int = -1
var marathon_total: int = -1

func _init(full_name_: String, description_: String, grid_data_: Dictionary, tutorial_: String) -> void:
	full_name = full_name_
	description = description_
	grid_data = grid_data_
	tutorial = tutorial_

func get_data() -> Dictionary:
	var data := {
		version = VERSION,
		full_name = full_name,
		grid_data = grid_data,
	}
	if not tutorial.is_empty():
		data.tutorial = tutorial
	if not description.is_empty():
		data.description = description
	if not seed_str.is_empty():
		data.seed_str = seed_str
	if manually_seeded:
		data.manually_seeded = true
	if difficulty != -1:
		data.difficulty = difficulty
		if marathon_left != -1:
			data.marathon_left = marathon_left
			data.marathon_total = marathon_total
	return data

static func load_data(data_: Variant) -> LevelData:
	if data_ == null:
		return null
	var data: Dictionary = data_
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	var level_data := LevelData.new(data.full_name, data.get("description", ""), data.grid_data, data.get("tutorial", ""))
	level_data.difficulty = data.get("difficulty", -1)
	level_data.marathon_left = data.get("marathon_left", -1)
	level_data.marathon_total = data.get("marathon_total", -1)
	level_data.seed_str = data.get("seed_str", "")
	level_data.manually_seeded = data.get("manually_seeded", false)
	return level_data

