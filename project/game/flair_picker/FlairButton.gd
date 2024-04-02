extends Control

var idx

func setup(flair_data, new_idx):
	idx = new_idx
	%Flair.text = "  %s  " % flair_data.text
	%Flair.add_theme_color_override("font_color", flair_data.color)
	var outline_color = Global.get_contrast_outline(flair_data.color)
	%Flair.get_node("BG").modulate = outline_color
	%Reason.text = flair_data.description
