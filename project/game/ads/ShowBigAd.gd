class_name ShowBigAd
extends Control

var marathon_dif := -1
var marathon_left := -1
var marathon_seed := ""

func _ready() -> void:
	if not Global.is_mobile:
		TransitionManager.pop_scene()
		return
	await AdManager.show_big_ad(exit_ad)

func exit_ad() -> void:
	if is_inside_tree():
		AdManager.destroy_big_ad()
		if marathon_dif != -1:
			var random_hub: RandomHub = TransitionManager.stack.back()
			await random_hub.continue_marathon(marathon_dif, marathon_left, marathon_seed, true)
		elif Global.play_new_dif_again != -1:
			TransitionManager.stack.back()._play_new_level_again()
		else:
			TransitionManager.pop_scene()

