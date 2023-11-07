extends Control

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.

func _on_run_pressed():
	GridTests.new().run_all_tests()
	print("All tests passed!")
