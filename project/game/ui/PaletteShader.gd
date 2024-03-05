extends CanvasLayer

enum Palette {
	None,
	Gray,
	Orange,
}

const PALETTES = [
	["NONE", Color()],
	["GRAY", Color(1.0, 1.0, 1.0)],
	["ORANGE", Color(1.77, 1.19, 1.0)]
]

func _ready():
	Profile.palette_changed.connect(_on_palette_changed)
	disable_palette()


func get_palettes():
	return PALETTES


func disable_palette():
	$ColorRect.hide()


func enable_palette(idx):
	if idx <= 0:
		disable_palette()
		return
	$ColorRect.show()
	if PALETTES.size() > idx:
		$ColorRect.material.set_shader_parameter("palette_color", PALETTES[idx][1])


func _on_palette_changed():
	enable_palette(Profile.get_option("palette"))
	
