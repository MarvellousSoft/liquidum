# Won't be uploaded to workshop!
class_name EditorLevelMetadata

var full_name: String
var steam_id: int

func _init(full_name_: String, steam_id_ := -1) -> void:
	full_name = full_name_
	steam_id = steam_id_

static func load_data(data: Dictionary) -> EditorLevelMetadata:
	return EditorLevelMetadata.new(data.full_name, data.steam_id)

func get_data() -> Dictionary:
	return {
		full_name = full_name,
		steam_id = steam_id,
	}
