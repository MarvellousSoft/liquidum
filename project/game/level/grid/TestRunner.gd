extends Control

@onready var g1: GridView = $Grid1
@onready var g2: GridView = $Grid2

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.

func _on_run_pressed():
	$Tests.run_all_tests()
	print("All tests passed!")

func _on_tests_show_grids(s1: String, s2: String):
	g1.setup(s1)
	g2.setup(s2)


func _on_gen_pressed():
	var rseed := randi() % 10000
	if $Seed.text != "":
		rseed = int($Seed.text)
	else:
		$Seed.placeholder_text = "Seed: %d" % rseed
	var gen := Generator.new(rseed)
	var g:= gen.generate(6, 6, false)
	var sol_str := g.to_str()
	g.clear_water_air()
	g1.setup(sol_str)
	g2.setup(g.to_str())


func _on_auto_solve_pressed():
	g2.auto_solve()


func _on_grid_2_updated():
	if $GodMode.button_pressed:
		g2.auto_solve(false, false)


func _on_paste_pressed():
	g2.setup(DisplayServer.clipboard_get())


func _on_full_solve_pressed():
	var r := g2.full_solve()
	print("Level is %s" % SolverModel.SolveResult.find_key(r))
