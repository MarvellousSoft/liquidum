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
	return SteamFlair.new(id, FlairManager.get_flair_amount() - 1)

func apply_to_label(label: Label, bg_alpha := 1.0) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.self_modulate = color
	var contrast_color: Color = Global.get_contrast_background(color)
	contrast_color.a = bg_alpha
	label.get_node("BG").modulate = contrast_color
