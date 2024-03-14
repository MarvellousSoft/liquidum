class_name ShowBigAd
extends Control

var marathon_dif := -1
var marathon_left := -1
var marathon_total := -1
var seed_str := ""
var manually_seeded := false
var marathon_time := -1.0
var marathon_mistakes := -1
var is_weekly := false

func _ready() -> void:
	if not Global.is_mobile:
		TransitionManager.pop_scene()
		return
	await AdManager.show_big_ad(exit_ad)

func exit_ad() -> void:
	if is_inside_tree():
		AdManager.destroy_big_ad()
		if is_weekly:
			var main_menu: Node = TransitionManager.stack.back()
			await main_menu.get_node("%WeeklyButton").gen_and_play(false)
		elif marathon_dif != -1:
			var random_hub: RandomHub = TransitionManager.stack.back()
			await random_hub.continue_marathon(marathon_dif, marathon_left, marathon_total, seed_str, manually_seeded, true, marathon_time, marathon_mistakes)
		elif Global.play_new_dif_again != -1:
			var last_scene = TransitionManager.stack.back()
			if last_scene is RandomHub:
				last_scene._play_new_level_again()
			else:
				last_scene.get_node("%ExtraLevelHub")._play_new_endless()
		else:
			TransitionManager.pop_scene()
	else:
		push_warning("Not inside tree")

