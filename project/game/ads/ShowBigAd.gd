extends Control


func _ready() -> void:
	if not Global.is_mobile:
		TransitionManager.pop_scene()
		return
	await AdManager.show_big_ad(exit_ad)

func exit_ad() -> void:
	if is_inside_tree():
		AdManager.destroy_big_ad()
		TransitionManager.pop_scene()

