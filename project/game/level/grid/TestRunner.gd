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
	var s := DESIRED_W / g2.get_grid_size().x
	g1.scale = Vector2(s, s)
	g2.scale = Vector2(s, s)

func all_strategies() -> Array:
	return SolverModel.STRATEGY_LIST.keys()


func _on_auto_solve_pressed():
	g2.apply_strategies(all_strategies())


func _on_grid_2_updated():
	if $GodMode.button_pressed:
		g2.apply_strategies(all_strategies(), false, false)


func _on_paste_pressed():
	g2.setup(GridImpl.from_str(DisplayServer.clipboard_get(), GridModel.LoadMode.Solution))
	scale_grids()


func _on_full_solve_pressed():
	var r := g2.full_solve(all_strategies())
	var solve_type: String = SolverModel.SolveResult.find_key(r)
	print("Level is %s" % solve_type)
	$SolvedType.text = solve_type
