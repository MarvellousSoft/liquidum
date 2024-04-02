class_name SelectableFlair

# 1-4 characters
var text: String
var color: Color
var description: String

func _init(text_: String, color_: Color, description_: String) -> void:
	text = text_
	color = color_
	description = description_

func to_steam_flair() -> Flair:
	return Flair.new(
		text,
		color,
	)
