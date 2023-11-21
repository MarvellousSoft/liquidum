extends TextureButton

const ALPHA_SPEED = 8.0

@onready var BG = $BG

var hover := false


func _ready():
	BG.modulate.a = 0.0


func _process(dt):
	if hover:
		BG.modulate.a = min(BG.modulate.a + ALPHA_SPEED*dt, 1.0)
	else:
		BG.modulate.a = max(BG.modulate.a - ALPHA_SPEED*dt, 0.0)


func _on_mouse_entered():
	hover = true


func _on_mouse_exited():
	hover = false
