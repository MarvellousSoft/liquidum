extends Node

func _enter_tree() -> void:
	AdManager.show_bottom_ad()

func _exit_tree() -> void:
	AdManager.destroy_bottom_ad()
