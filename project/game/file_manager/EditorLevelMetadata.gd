class_name EditorLevelMetadata

var full_name: String

func _init(full_name_: String) -> void:
	full_name = full_name_

static func load_data(data: Dictionary) -> EditorLevelMetadata:
	return EditorLevelMetadata.new(data.full_name)

func get_data() -> Dictionary:
	return {
		full_name = full_name,
	}
