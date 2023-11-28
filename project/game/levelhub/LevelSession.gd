extends Control

@onready var AnimPlayer = $AnimationPlayer
@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect


func _ready():
	AnimPlayer.play("float", -1, randf_range(.5, .75))
	AnimPlayer.seek(randf_range(0.0, AnimPlayer.current_animation_length))


func enable() -> void:
	AnimPlayer.play("float", -1, randf_range(.5, .75))
	MainButton.disabled = false
	ShaderEffect.show()


func disable() -> void:
	AnimPlayer.play("float", -1, randf_range(.2, .3))
	MainButton.disabled = true
	ShaderEffect.hide()


func setup(_num_levels) -> void:
	pass
