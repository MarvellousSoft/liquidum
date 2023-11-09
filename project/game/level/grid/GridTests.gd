class_name GridTests
extends Node

signal show_grids(g1: String, g2: String)

const TopLeft := E.Corner.TopLeft
const TopRight := E.Corner.TopRight
const BottomLeft := E.Corner.BottomLeft
const BottomRight := E.Corner.BottomRight
const Left := E.Side.Left
const Right := E.Side.Right
const Top := E.Side.Top
const Bottom := E.Side.Bottom
const Dec := E.Diagonal.Dec
const Inc := E.Diagonal.Inc

var fail := 0

func run_all_tests() -> void:
	for method in get_method_list():
		var t_name: String = method["name"]
		if t_name.begins_with("test_"):
			print("Running %s" % t_name)
			call(t_name)
			if fail > 0:
				call_deferred("do_fail")

func do_fail() -> void:
	assert(false)

func check(cond: bool) -> void:
	if not cond and fail == 0:
		assert(false)

func fail_later_if(cond: bool) -> void:
	if cond:
		fail += 1

func assert_grid_eq(a: String, b: String) -> void:
	a = a.dedent().strip_edges()
	b = b.dedent().strip_edges()
	if a != b:
		print("Grids differ:\n%s\n\n%s" % [a, b])
		show_grids.emit(a, b)
		
		fail_later_if(a != b)

func assert_can_solve(s: String) -> void:
	var g := str_grid(s)
	check(!g.are_hints_satisfied())
	SolverModel.new().apply_strategies(g)
	if !g.are_hints_satisfied():
		fail_later_if(true)
		show_grids.emit(s, g.to_str())


func get_rows(s : String) -> int:
	return (s.count('\n') + 1) / 2


func get_cols(s: String) -> int:
	return s.find('\n') / 2


func str_grid(s: String) -> GridModel:
	return GridImpl.from_str(s)

func test_simple() -> void:
	var simple := """
	wwwx
	L../
	#..w
	L╲_╲
	"""
	var g := GridImpl.create(2, 2)
	check(!g.get_cell(0, 0).water_full())
	g.load_from_str(simple)
	# Check waters make sense
	check(g.get_cell(0, 0).water_full())
	for corner in [BottomLeft, BottomRight, TopLeft, TopRight]:
		check(g.get_cell(0, 0).water_at(corner))
	check(g.get_cell(0, 1).water_at(TopLeft))
	check(!g.get_cell(0, 1).water_at(BottomRight))
	check(g.get_cell(1, 1).water_at(TopRight))
	check(!g.get_cell(1, 1).water_at(BottomLeft))
	# Check air
	check(!g.get_cell(0, 0).air_at(TopLeft))
	check(!g.get_cell(0, 1).air_at(TopLeft))
	check(g.get_cell(0, 1).air_at(BottomRight))
	check(!g.get_cell(1, 0).air_at(BottomLeft) and !g.get_cell(1, 0).water_at(BottomRight))
	# Check block
	check(!g.get_cell(1, 0).block_full())
	check(g.get_cell(1, 0).block_at(BottomLeft))
	# Check diag walls
	check(!g.get_cell(0, 0).wall_at(E.Walls.DecDiag))
	check(g.get_cell(0, 1).wall_at(E.Walls.IncDiag))
	check(!g.get_cell(0, 1).wall_at(E.Walls.DecDiag))
	check(g.get_cell(1, 1).wall_at(E.Walls.DecDiag))
	# Check walls
	check(g.get_cell(0, 0).wall_at(E.Walls.Left))
	check(!g.get_cell(0, 0).wall_at(E.Walls.Right))
	check(g.get_cell(0, 0).wall_at(E.Walls.Bottom))
	check(g.get_cell(0, 0).wall_at(E.Walls.Top))
	check(!g.get_cell(1, 1).wall_at(E.Walls.Left))
	check(g.get_cell(1, 1).wall_at(E.Walls.Right))

	assert_grid_eq(simple, g.to_str())

func test_put_water_one_cell() -> void:
	var g := str_grid("..\n..")
	check(g.get_cell(0, 0).nothing_full())
	check(g.get_cell(0, 0).nothing_at(TopLeft))
	g.get_cell(0, 0).put_water(BottomRight)
	assert_grid_eq(g.to_str(), "ww\nL.")
	g = str_grid("..\nL╲")
	g.get_cell(0, 0).put_water(TopRight)
	assert_grid_eq(g.to_str(), ".w\nL╲")
	g.get_cell(0, 0).put_water(TopRight)
	assert_grid_eq(g.to_str(), ".w\nL╲")
	g.get_cell(0, 0).put_water(BottomLeft)
	assert_grid_eq(g.to_str(), "ww\nL╲")
	g.undo()
	assert_grid_eq(g.to_str(), ".w\nL╲")
	g.redo()
	assert_grid_eq(g.to_str(), "ww\nL╲")

const big_level := """
......
|....╲
......
|╲./|.
......
L../.╲
#.....
L╲_╲_.
"""

func test_water_big_level() -> void:
	var g := str_grid(big_level)
	# Test a "bucket" of water
	g.get_cell(1, 1).put_water(TopLeft)
	g.get_cell(2, 2).put_water(BottomLeft)
	assert_grid_eq(g.to_str(), """
......
|....╲
.ww...
|╲./|.
...ww.
L../.╲
#..www
L╲_╲_.
	""")
	# Test flooding up through "caves"
	g.undo()
	g.get_cell(1, 1).put_water(BottomRight)
	check(g.get_cell(1, 0).water_at(BottomLeft))
	# Other direction
	g.undo()
	check(!g.get_cell(1, 1).water_at(BottomRight))
	g.get_cell(1, 0).put_water(BottomLeft)
	check(g.get_cell(1, 1).water_at(BottomRight))
	g.undo()
	g.get_cell(0, 0).put_water(TopLeft)
	g.undo()
	g.redo()
	g.get_cell(3, 1).put_water(BottomLeft)
	g.redo()
	g.redo()
	assert_grid_eq(g.to_str(), """
wwwww.
|....╲
.ww.ww
|╲./|.
.....w
L../.╲
#ww...
L╲_╲_.
	""")
	g.get_cell(3, 0).remove_water_or_air(TopRight)
	g.get_cell(1, 0).put_water(BottomLeft)
	g.get_cell(1, 2).put_air(BottomRight)
	g.get_cell(1, 1).put_air(BottomRight)
	assert_grid_eq(g.to_str(), """
......
|....╲
.wwxxx
|╲./|.
www..w
L../.╲
#.....
L╲_╲_.
	""")
	check(g.hint_col(0) == -1.)
	g.set_hint_col(0, 1.5)
	check(g.hint_col(0) == 1.5)
	g.set_hint_row(1, 1.)
	check(g.are_hints_satisfied())
	g.set_hint_col(2, 0.5)
	check(g.are_hints_satisfied())
	g.set_hint_row(0, 0.5)
	check(!g.are_hints_satisfied())

func test_simple_solve() -> void:
	var g := str_grid("""
	...1.3.
	2......
	.|╲_/./
	2......
	.L._.L.
""")
	check(!g.are_hints_satisfied())
	check(g.hint_col(0) == -1.)
	check(g.hint_col(1) == 0.5)
	check(g.hint_col(2) == 1.5)
	check(g.hint_row(0) == 1.)
	check(g.hint_row(1) == 1.)
	g.get_cell(0, 1).put_water(BottomRight)
	g.get_cell(1, 2).put_water(BottomLeft)
	# Successfully solved, hooray!
	check(g.are_hints_satisfied())
	g.undo()
	g.undo()
	check(!g.are_hints_satisfied())
	SolverModel.new().apply_strategies(g)
	assert_grid_eq(g.to_str(), """
	...1.3.
	2x.....
	.|╲_/./
	2xxxxww
	.L._.L.
	""")

func test_solver_rows() -> void:
	var solver := SolverModel.new()
	var g := str_grid("""
	.....
	2....
	.L.|.
	3....
	.L._╲
	""")
	solver.apply_strategies(g)
	assert_grid_eq(g.to_str(), """
	.....
	2wwxx
	.L.|.
	3wwwx
	.L._╲
	""")
	solver.apply_strategies(str_grid("""
	.....
	2.ww.
	.|╲./
	.....
	.L._.
	"""))

func test_remove_water_bug() -> void:
	var g := str_grid("""
	xx
	|.
	ww
	L.
	""")
	g.get_cell(1, 0).remove_water_or_air(BottomLeft)
	assert_grid_eq(g.to_str(), """
	xx
	|.
	..
	L.
	""")

func test_can_solve() -> void:
	assert_can_solve(".2.\n...\n...")
	assert_can_solve("""
	.4...
	2....
	._.L.
	2....
	...|.
	2....
	._.L.
	""")
	assert_can_solve(".2.\n...\n...\n...\n...\n...\n...")

func _flood_all(bef: String, aft: String) -> void:
	var g := str_grid(bef)
	g.flood_all()
	assert_grid_eq(g.to_str(), aft)
	check(!g.flood_all())

func test_flood_all() -> void:
	_flood_all(".w\n|.\n..\nL.", "ww\n|.\nww\nL.")
	_flood_all("ww\n|.\nxx\nL.", "ww\n|.\nww\nL.")
	_flood_all(".w\n|╲\n..\nL.", ".w\n|╲\n..\nL.")
	_flood_all(".w\n|/\n..\nL.", ".w\n|/\nww\nL.")
