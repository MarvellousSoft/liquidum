extends Control


func _ready() -> void:
	Background.get_node("AnimationPlayer").play("RESET")
	Background.get_node("Particles").emitting = false
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if name.contains("Mobile"):
		img.save_png("res://assets/images/splash_mobile.png")
	else:
		img.save_png("res://assets/images/splash_image.PNG")
