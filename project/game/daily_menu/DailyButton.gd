extends Button

func _enter_tree() -> void:
	call_deferred("_update")

func _update() -> void:
	pass
