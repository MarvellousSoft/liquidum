extends ColorRect


@onready var AnimPlayer = $AnimationPlayer


func _ready():
	material = material.duplicate(false)
	

func play():
	AnimPlayer.play("grow")


func set_pos(pos : Vector2) -> void:
	material.set_shader_parameter(&"center", pos)
