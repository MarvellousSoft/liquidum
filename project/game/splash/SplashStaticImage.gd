extends Control


func _ready() -> void:
	Background.get_node("AnimationPlayer").play("RESET")
	Background.get_node("Particles").emitting = false
