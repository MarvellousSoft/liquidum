class_name SelectableFlair

var id: int
# 1-4 characters
var text: String
var color: Color
var description: String

func _init(id_: int, text_: String, color_: Color, description_: String) -> void:
	id = id_
	text = text_
	color = color_
	description = description_

func to_steam_flair() -> SteamFlair:
	return SteamFlair.new(id)
