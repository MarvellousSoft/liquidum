extends TextureRect

const ALPHA_SPEED = 4.0

signal pressed_main_button(i: int, j: int)
signal pressed_second_button(i: int, j: int)
signal mouse_entered_button(i: int, j: int)

@onready var AnimPlayer = $AnimationPlayer

var i : int
var j : int
var active := false


func _process(dt):
	if active:
		self_modulate.a = min(self_modulate.a + ALPHA_SPEED*dt, 1.0)
		if self_modulate.a > 0.0:
			show()
	else:
		self_modulate.a = max(self_modulate.a - ALPHA_SPEED*dt, 0.0)
		if self_modulate.a <= 0.0:
			hide()


func setup(new_i : int, new_j : int) -> void:
	self_modulate.a = 0.0
	i = new_i
	j = new_j


func enable() -> void:
	active = true


func disable() -> void:
	active = false


func error() -> void:
	AnimPlayer.play("error")


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					pressed_main_button.emit(i, j)
				MOUSE_BUTTON_RIGHT:
					pressed_second_button.emit(i, j)


func _on_mouse_entered():
	mouse_entered_button.emit(i, j)
