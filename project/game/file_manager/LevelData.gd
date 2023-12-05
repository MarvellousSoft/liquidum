class_name LevelData

const VERSION := 1

var full_name: String
var grid_data: Dictionary
var tutorial: String

func _init(full_name_: String, grid_data_: Dictionary, tutorial_: String) -> void:
	full_name = full_name_
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
	return data

static func load_data(data_: Variant) -> LevelData:
	if data_ == null:
		return null
	var data: Dictionary = data_
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	return LevelData.new(data.full_name, data.grid_data, data.get("tutorial", ""))

