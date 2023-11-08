extends Control

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.

func _on_run_pressed():
	$Tests.run_all_tests()
	print("All tests passed!")

func _on_tests_show_grids(g1: String, g2: String):
	$Grid1.show()
	$Grid2.show()
	$Grid1.setup(g1)
	$Grid2.setup(g2)
