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
        # TODO: Remove this when we don't need custom dark mode
        # color for flairs anymore
        Color(0.270588, 0.803922, 0.698039, 1),
    )