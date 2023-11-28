extends Control

@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect

var my_session := -1
var my_number := -1

func setup(session, number):
	my_session = session
	my_number = number


func enable() -> void:
	MainButton.disabled = false
	ShaderEffect.show()


func disable() -> void:
	MainButton.disabled = true
	ShaderEffect.hide()
