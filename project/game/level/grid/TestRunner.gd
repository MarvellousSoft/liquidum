extends Control

const DESIRED_W := 780.0

@onready var g1: GridView = $Grid1
@onready var g2: GridView = $Grid2

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.

func _ready() -> void:
	$BrushPicker.setup(true)

func _on_run_pressed():
	$Tests.run_all_tests()

func _on_tests_show_grids(s1: String, s2: String):
	g1.setup(GridImpl.from_str(s1, GridModel.LoadMode.Testing))
	g2.setup(GridImpl.from_str(s2, GridModel.LoadMode.Testing))
	scale_grids()


func scale_grids() -> void:
	await get_tree().process_frame
	var s := DESIRED_W / g1.get_grid_size().x
	g1.scale = Vector2(s, s)
	g2.scale = Vector2(s, s)

func gen_puzzle() -> GridModel:
	while true:
		var rseed := randi() % 100000
		if $Seed.text != "":
			rseed = int($Seed.text)
		else:
			$Seed.placeholder_text = "Seed: %d" % rseed
		var gen := Generator.new(rseed)
		var g := gen.generate($Rows.value, $Cols.value, $Diags.button_pressed, false)
		if $Interesting.button_pressed and $Seed.text == "":
			g.clear_content()
			var r := SolverModel.new().full_solve(g)
			if r != SolverModel.SolveResult.SolvedUnique:
				print("Generated %s. Trying again." % SolverModel.SolveResult.find_key(r))
				await get_tree().process_frame
				continue
		return g
	assert(false, "Unreachable")
	return null

func _on_gen_pressed() -> void:
	$Gen.disabled = true
	var g := await gen_puzzle()
	$SolvedType.text = ""
	var sol_str := g.to_str()
	g1.setup(GridImpl.from_str(sol_str, GridModel.LoadMode.SolutionNoClear))
	g.clear_content()
	# Solver needs to play with it, can't be limited by the solution
	g2.setup(GridImpl.from_str(g.to_str(), GridModel.LoadMode.Editor))
	scale_grids()
	$Gen.disabled = false


func _on_auto_solve_pressed():
	g2.auto_solve()


func _on_grid_2_updated():
	if $GodMode.button_pressed:
		g2.auto_solve(false, false)


func _on_paste_pressed():
	g2.setup(GridImpl.from_str(DisplayServer.clipboard_get(), GridModel.LoadMode.Editor))
	scale_grids()


func _on_full_solve_pressed():
	var r := g2.full_solve()
	var solve_type: String = SolverModel.SolveResult.find_key(r)
	print("Level is %s" % solve_type)
	$SolvedType.text = solve_type
