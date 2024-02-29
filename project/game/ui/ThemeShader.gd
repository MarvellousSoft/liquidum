extends CanvasLayer

const THEMES = [
	["GRAY_THEME", Color(1.0, 1.0, 1.0)],
	["ORANGE_THEME", Color(1.77, 1.19, 1.0)]
]

# Called when the node enters the scene tree for the first time.
func _ready():
	disable_theme()


func disable_theme():
	$ColorRect.hide()


func enable_theme(idx):
	$ColorRect.show()
	if THEMES.size() > idx:
		$ColorRect.material.set_shader_parameter("theme_color", THEMES[idx][1])
