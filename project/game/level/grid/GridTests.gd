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
const Satisfied := E.HintStatus.Satisfied
const Wrong := E.HintStatus.Wrong
const Normal := E.HintStatus.Normal

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

func assert_can_solve(s: String, result := true) -> void:
	var g := str_grid(s)
	check(!g.are_hints_satisfied())
	SolverModel.new().apply_strategies(g)
	if g.are_hints_satisfied() != result:
		fail_later_if(true)
		print("Not satisfied:\n", g.to_str())
		show_grids.emit(s, g.to_str())

func assert_cant_solve(s: String) -> void:
	assert_can_solve(s, false)


func get_rows(s : String) -> int:
	return (s.count('\n') + 1) / 2


func get_cols(s: String) -> int:
	return s.find('\n') / 2


func str_grid(s: String) -> GridModel:
	var g := GridImpl.from_str(s, GridModel.LoadMode.FreeEdit)
	# Let's check it loads and unloads correctly
	var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.FreeEdit)
	assert(g.equal(g2))
	return g

func test_simple() -> void:
	var simple := """
	wwwx
	L../
	#..w
	L╲_╲
	"""
	var g := GridImpl.create(2, 2)
	check(!g.get_cell(0, 0).water_full())
	g.load_from_str(simple, GridModel.LoadMode.FreeEdit)
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
	g.get_cell(3, 0).remove_content(TopRight)
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
	check(g.col_hints()[0].water_count == -1.)
	g.set_hint_col(0, 1.5)
	check(g.col_hints()[0].water_count == 1.5)
	g.set_hint_row(1, 1.)
	check(g.are_hints_satisfied())
	g.set_hint_col(2, 0.5)
	check(g.are_hints_satisfied())
	g.set_hint_row(0, 0.5)
	check(!g.are_hints_satisfied())

func test_simple_solve() -> void:
	var g := str_grid("""
	h..1.3.
	2......
	.|╲_/./
	2......
	.L._.L.
""")
	check(!g.are_hints_satisfied())
	check(g.col_hints()[0].water_count == -1.)
	check(g.col_hints()[1].water_count == 0.5)
	check(g.col_hints()[2].water_count == 1.5)
	check(g.row_hints()[0].water_count == 1.)
	check(g.row_hints()[1].water_count == 1.)
	g.get_cell(0, 1).put_water(BottomRight)
	g.get_cell(1, 2).put_water(BottomLeft)
	# Successfully solved, hooray!
	check(g.are_hints_satisfied())
	g.undo()
	g.undo()
	check(!g.are_hints_satisfied())
	SolverModel.new().apply_strategies(g)
	assert_grid_eq(g.to_str(), """
	h..1.3.
	2xxxwwx
	.|╲_/./
	2xxxxww
	.L._.L.
	""")

func test_solver_rows() -> void:
	var solver := SolverModel.new()
	var g := str_grid("""
	h....
	2....
	.L.|.
	3....
	.L._╲
	""")
	solver.apply_strategies(g)
	assert_grid_eq(g.to_str(), """
	h....
	2wwxx
	.L.|.
	3wwwx
	.L._╲
	""")
	solver.apply_strategies(str_grid("""
	h....
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
	g.get_cell(1, 0).remove_content(BottomLeft)
	assert_grid_eq(g.to_str(), """
	xx
	|.
	..
	L.
	""")

func test_can_solve() -> void:
	assert_can_solve("h2.\n...\n...")
	assert_can_solve("""
	h4...
	2....
	._.L.
	2....
	...|.
	2....
	._.L.
	""")
	assert_can_solve("h2.\n...\n...\n...\n...\n...\n...")
	assert_can_solve("""
	+boats=1
	b...
	.h..
	1...
	....
	....
	....
	""")
	assert_can_solve("""
	+boats=1
	b.1.
	.h..
	....
	....
	....
	....
	""")

func test_cant_solve() -> void:
	# Can't guess water level
	assert_cant_solve("""
	+boats=1
	b.1.
	.h..
	....
	....
	....
	....
	....
	....
	""")

func test_guess_boat() -> void:
	var g := str_grid("""
	+boats=1
	b....
	1....
	.|...
	.....
	.L._.
	""")
	SolverModel.new().full_solve(g)
	check(g.are_hints_satisfied())

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

func test_boat_hint() -> void:
	var s := """
	b...
	.h2.
	10..
	..|.
	.2..
	..L.
	"""
	assert_grid_eq(str_grid(s).to_str(), s)

func test_boat_place_remove() -> void:
	var g := str_grid("""
	+boats=1
	b.......
	.h......
	1.......
	........
	.6......
	........
	........
	........
	""")
	assert(!g.get_cell(0, 1).put_boat())
	g.get_cell(1, 0).put_water(BottomLeft)
	assert(!g.are_hints_satisfied())
	assert(!g.get_cell(0, 1).has_boat())
	assert(g.get_cell(0, 1).put_boat())
	assert(g.get_cell(0, 1).has_boat())
	assert(g.are_hints_satisfied())
	# Water should destroy boat
	g.get_cell(0, 0).put_water(BottomRight)
	assert(!g.get_cell(0, 1).has_boat())
	assert(g.get_cell(0, 1).water_full())
	g.undo()
	assert(g.are_hints_satisfied())
	# Removing water should destroy boat
	g.get_cell(1, 2).remove_content(TopRight)
	assert(!g.get_cell(0, 1).has_boat())
	g.undo()
	assert(g.are_hints_satisfied())
	# Air should flood through boats without deleting them
	g.get_cell(0, 0).put_air(TopLeft, true, true)
	assert(g.get_cell(0, 0).air_full())
	assert(g.get_cell(0, 1).has_boat())
	assert(g.get_cell(0, 2).air_full())

func test_subset_sum() -> void:
	assert_can_solve("""
	h........2.
	2..........
	.L._._.|.L.
	6..........
	.L._.L._.L.
	""")

func test_load_content_only() -> void:
	var g := str_grid("..\n|.\n..\nL.\n")
	assert_grid_eq(g.to_str(), "..\n|.\n..\nL.\n")
	# Assume we saved the puzzle to file, and the user edited it to add a wall
	# and make the level easier, let's not accept that
	g.load_from_str("ww\nL.\n..\nL.\n", GridModel.LoadMode.ContentOnly)
	assert_grid_eq(g.to_str(), "ww\n|.\nww\nL.")

func test_aquarium_hints() -> void:
	var g := str_grid("+aqua=1\n..\n..\n..\n..")
	assert(!g.are_hints_satisfied())
	assert(g.grid_hints().expected_aquariums == [1.])
	assert(g.aquarium_hints_status() == [Normal])
	g.get_cell(0, 0).put_water(TopLeft)
	assert(g.aquarium_hints_status() == [Wrong])
	g.undo()
	g.get_cell(1, 0).put_water(TopLeft)
	assert(g.aquarium_hints_status() == [Satisfied])
	assert(g.are_hints_satisfied())

func test_together_rules() -> void:
	var g := str_grid("""
	h......
	4......
	}L.L.L.
	""")
	g.get_cell(0, 0).put_water(TopRight)
	g.get_cell(0, 2).put_water(TopRight)
	assert(!g.are_hints_satisfied())
	g.get_cell(0, 2).remove_content(TopRight)
	g.get_cell(0, 1).put_water(TopRight)
	assert(g.are_hints_satisfied())
	# Same but vertical
	g = str_grid("""
	h4}
	...
	.L.
	...
	.L.
	...
	.L.
	""")
	g.get_cell(0, 0).put_water(TopRight)
	g.get_cell(2, 0).put_water(TopRight)
	assert(!g.are_hints_satisfied())
	g.get_cell(2, 0).remove_content(TopRight)
	g.get_cell(1, 0).put_water(TopRight)
	assert(g.are_hints_satisfied())
