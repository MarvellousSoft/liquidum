extends Node

func _enter_tree() -> void:
	AdManager.show_ad_bottom()

func _exit_tree() -> void:
	AdManager.destroy_ad_view()
