extends Control


func _ready() -> void:
	Background.get_node("AnimationPlayer").play("RESET")
	Background.get_node("Particles").emitting = false
	var viewport := get_viewport()
	if name.contains("Mobile"):
		viewport.size = Vector2(720, 1280)
	else:
		viewport.size = Vector2(3840, 2160)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if name.contains("Mobile"):
		img.save_png("res://assets/images/splash_mobile.png")
	else:
		img.save_png("res://assets/images/splash_image.PNG")
