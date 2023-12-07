# Won't be uploaded to workshop!
class_name EditorLevelMetadata

var steam_id: int

func _init(steam_id_ := -1) -> void:
	steam_id = steam_id_

static func load_data(data: Dictionary) -> EditorLevelMetadata:
	return EditorLevelMetadata.new(data.steam_id)

func get_data() -> Dictionary:
	return {
		steam_id = steam_id,
	}
