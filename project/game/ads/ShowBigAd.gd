extends Control


func _ready() -> void:
	if not Global.is_mobile:
		return TransitionManager.pop_scene()
	AdManager.show_big_ad(exit_ad)

func exit_ad() -> void:
	if is_inside_tree():
		AdManager.destroy_ads()
		TransitionManager.pop_scene()

