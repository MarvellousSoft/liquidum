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
	fail = 0
	for method in get_method_list():
		var t_name: String = method["name"]
		if t_name.begins_with("test_"):
			var watch := Stopwatch.new()
			var prev_fail := fail
			call(t_name)
			print("[%.1fms] Ran %s" % [watch.elapsed() * 1000., t_name])
			if fail > prev_fail:
				print("FAILED!")

	if fail > 0:
		print("(%d) Some tests failed :(" % fail)
	else:
		print("All tests passed!")

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
		fail_later_if(true)
		if fail == 1:
			show_grids.emit(a, b)

func all_strategies() -> Array:
	return SolverModel.STRATEGY_LIST.keys()

func apply_strategies(s: String, strategies := []) -> GridImpl:
	var g := str_grid(s)
	check(!g.are_hints_satisfied(true))
	if strategies.is_empty():
		strategies = all_strategies()
	SolverModel.new().apply_strategies(g, strategies)
	return g

func assert_can_solve(s: String, strategies := [], result := true) -> void:
	var g := apply_strategies(s, strategies)
	if g.are_hints_satisfied(true) != result:
		fail_later_if(true)
		if result:
			print("Not solved:")
		else:
			print("Solved but shouldn't:")
		print(g.to_str())
		if fail == 1:
			show_grids.emit(s, g.to_str())

func assert_cant_solve(s: String, strategies := []) -> void:
	assert_can_solve(s, strategies, false)

func assert_apply_strategies(s: String, res: String = "", strategies := []) -> void:
	if res == "":
		# W and X show future water and nowater
		res = s.replace("W", "w").replace("X", "x")
		s = s.replace("W", ".").replace("X", ".")
	assert_grid_eq(apply_strategies(s, strategies).to_str(), res)

func get_rows(s : String) -> int:
	return (s.count('\n') + 1) / 2


func get_cols(s: String) -> int:
	return s.find('\n') / 2


func str_grid(s: String) -> GridModel:
	var g := GridImpl.from_str(s, GridModel.LoadMode.Testing)
	# Let's check it loads and unloads correctly
	var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
	assert(g.equal(g2))
	return g

func test_simple() -> void:
	var simple := """
	wwwx
	L../
	#..w
	L╲_╲
	"""
	var g := GridImpl.new(2, 2)
	check(!g.get_cell(0, 0).water_full())
	g.load_from_str(simple, GridModel.LoadMode.Testing)
	# Check waters make sense
	check(g.get_cell(0, 0).water_full())
	for corner in [BottomLeft, BottomRight, TopLeft, TopRight]:
		check(g.get_cell(0, 0).water_at(corner))
	check(g.get_cell(0, 1).water_at(TopLeft))
	check(!g.get_cell(0, 1).water_at(BottomRight))
	check(g.get_cell(1, 1).water_at(TopRight))
	check(!g.get_cell(1, 1).water_at(BottomLeft))
	# Check nowater
	check(!g.get_cell(0, 0).nowater_at(TopLeft))
	check(!g.get_cell(0, 1).nowater_at(TopLeft))
	check(g.get_cell(0, 1).nowater_at(BottomRight))
	check(!g.get_cell(1, 0).nowater_at(BottomLeft) and !g.get_cell(1, 0).water_at(BottomRight))
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
	g.get_cell(1, 2).put_nowater(BottomRight)
	g.get_cell(1, 1).put_nowater(BottomRight)
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
	g.col_hints()[0].water_count = 1.5
	check(g.col_hints()[0].water_count == 1.5)
	g.row_hints()[1].water_count = 1.
	check(g.are_hints_satisfied())
	g.col_hints()[2].water_count = 0.5
	check(g.are_hints_satisfied())
	g.row_hints()[0].water_count = 0.5
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
	SolverModel.new().apply_strategies(g, all_strategies())
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
	solver.apply_strategies(g, all_strategies())
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
	"""), all_strategies())

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
	B...
	.h..
	1...
	....
	....
	....
	""")
	assert_can_solve("""
	+boats=1
	B.1.
	.h..
	....
	....
	....
	....
	""")
	var col_with_halfcell := """
	h3.
	.%s.
	../
	...
	.L.
	...
	.L.
	"""
	assert_can_solve(col_with_halfcell % "#")
	assert_cant_solve(col_with_halfcell % ".")
	# Can't guess water level
	assert_cant_solve("""
	+boats=1
	B.1.
	.h..
	....
	....
	....
	....
	....
	....
	""")
	# Can guess the left boat but not the right unless it's X on top
	var grid_with_2_boats := """
	+boats=2
	##%s
	L.|.
	%s
	|.|.
	%s
	L.L.
	"""
	assert_grid_eq(apply_strategies(grid_with_2_boats % ["..", "....", "...."]).to_str(), grid_with_2_boats % ["xx", "bb..", "wwww"])
	assert_grid_eq(apply_strategies(grid_with_2_boats % ["..", "..xx", "...."]).to_str(), grid_with_2_boats % ["xx", "bbbb", "wwww"])
	assert_cant_solve("""
	+boats=1
	B1.
	.xx
	.|.
	...
	.|.
	.ww
	.L.
	""")
	assert_cant_solve("""
	+boats=1
	xx
	|.
	..
	|.
	ww
	L.
	""")
	var grid_with_1_boat_col := """
	+boats=1
	B%s.
	.%s
	.|.
	.%s
	.|.
	0%s
	.L.
	"""
	for s in ["BoatCol", "AllBoats"]:
		var h := "1" if s == "BoatCol" else "."
		assert_can_solve(grid_with_1_boat_col % [h, "..", "ww", "ww"], [s])
		assert_can_solve(grid_with_1_boat_col % [h, "xx", "xx", "ww"], [s])
		assert_can_solve(grid_with_1_boat_col % [h, "xx", "xx", ".."], [s])
		assert_grid_eq(apply_strategies(grid_with_1_boat_col % [h, "..", "..", ".."], [s]).to_str(), grid_with_1_boat_col % [h, "xx", "..", "ww"])
		assert_grid_eq(apply_strategies(grid_with_1_boat_col % [h, "xx", "..", ".."], [s]).to_str(), grid_with_1_boat_col % [h, "xx", "..", "ww"])
		assert_grid_eq(apply_strategies(grid_with_1_boat_col % [h, "..", "..", "ww"], [s]).to_str(), grid_with_1_boat_col % [h, "xx", "..", "ww"])
	# Using cross row-col boat elimination
	# Necessary because we don't have a X that means "no boat"
	var grid_two_boats := """
	+boats=%d
	B..0...
	%s......
	.|.....
	.wwwwww
	.L._._.
	"""
	assert_can_solve(grid_two_boats % [-1, "2"], ["BoatRow"])
	assert_can_solve(grid_two_boats % [2, "."], ["AllBoats"])
	assert_cant_solve(grid_two_boats % [-1, "."])
	assert_can_solve("""
	+boats=-1
	B1.
	.xx
	.|.
	.ww
	.L.
	0xx
	.|.
	.ww
	.L.
	""")
	var grid_row_1_boat := """
	+boats=-1
	B1.
	%sxx
	.|.
	%s..
	.|.
	.ww
	.L.
	"""
	assert_can_solve(grid_row_1_boat % [".", "0"])
	assert_can_solve(grid_row_1_boat % ["0", "."])
	assert_cant_solve(grid_row_1_boat % [".", "."])



func test_guess_boat() -> void:
	var g := str_grid("""
	+boats=1
	B....
	1....
	.|...
	.....
	.L._.
	""")
	SolverModel.new().full_solve(g, all_strategies(), func(): return false)
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
	B...
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
	B.......
	.h......
	1.......
	........
	.6......
	......_.
	........
	........
	""")
	# Can't place on top of wall
	assert(!g.get_cell(1, 2).put_boat())
	# Place water automatically below
	assert(g.get_cell(0, 1).put_boat())
	assert(g.get_cell(1, 0).water_full())
	g.undo()
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
	# NoWater should flood through boats without deleting them
	g.get_cell(0, 0).put_nowater(TopLeft, true, true)
	assert(g.get_cell(0, 0).nowater_full())
	assert(g.get_cell(0, 1).has_boat())
	assert(g.get_cell(0, 2).nowater_full())

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
	var g := str_grid("+aqua=1:1\n..\n..\n..\n..")
	assert(!g.are_hints_satisfied())
	assert(g.grid_hints().expected_aquariums == {1.: 1})
	assert(g.aquarium_hints_status() == Normal)
	g.get_cell(0, 0).put_water(TopLeft)
	assert(g.aquarium_hints_status() == Normal)
	g.undo()
	g.get_cell(1, 0).put_water(TopLeft)
	assert(g.aquarium_hints_status() == Satisfied)
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
	assert_can_solve("""
	h....
	.wwx.
	}L.L/
	""", ["TogetherRowBasic"])
	assert_can_solve("""
	h........
	5....w...
	}L/L.L/_.
	""")

func test_put_wall() -> void:
	var g := GridImpl.new(1, 2)
	g.get_cell(0, 0).put_water(TopLeft)
	g.get_cell(0, 0).put_wall(E.Walls.DecDiag)
	assert(!g.get_cell(0, 0).water_full())
	assert(g.get_cell(0, 0).water_at(BottomLeft))
	g.get_cell(0, 0).remove_content(BottomLeft, false)
	assert(g.get_cell(0, 0).water_at(TopRight))
	g.remove_wall_from_idx(0, 0, 1, 1, false)
	assert(g.get_cell(0, 0).water_at(BottomLeft))
	g = GridImpl.new(3, 3)
	g.put_wall_from_idx(3, 3, 0, 0)
	var dec_dig := """
	......
	|╲....
	......
	|..╲..
	......
	L._._╲
	"""
	assert_grid_eq(g.to_str(), dec_dig)
	g.undo()
	assert_grid_eq(g.to_str(), GridImpl.new(3, 3).to_str())
	g.put_wall_from_idx(0, 0, 3, 3)
	assert_grid_eq(g.to_str(), dec_dig)

func test_put_nowater_with_boat() -> void:
	var g := str_grid("""
	bb..
	|...
	w.ww
	L/L.
	""")
	g.get_cell(1, 1).put_nowater(BottomRight)
	assert_grid_eq(g.to_str(), """
	bb..
	|...
	w.xx
	L/L.
	""")

func test_resize() -> void:
	const initial := "ww\nL."
	var g := str_grid(initial)
	g.add_row()
	const with_row := "ww\n|.\nww\nL."
	assert_grid_eq(g.to_str(), with_row)
	g.undo()
	assert_grid_eq(g.to_str(), initial)
	g.redo()
	g.add_row()
	g.rem_row()
	assert_grid_eq(g.to_str(), with_row)
	g.add_col()
	assert_grid_eq(g.to_str(), "wwww\n|...\nwwww\nL._.")
	g.undo()
	assert_grid_eq(g.to_str(), with_row)
	g.redo()
	g.rem_col()
	assert_grid_eq(g.to_str(), with_row)

func test_solve_together() -> void:
	var s := ["TogetherRowBasic", "TogetherRowAdvanced"]
	assert_can_solve("""
	h....
	3w.w.
	}L/L/
	""", s)
	assert_grid_eq(apply_strategies("""
	h....
	2.w..
	}L/L/
	""", s).to_str(), """
	h....
	2.w.x
	}L/L/
	""")
	assert_grid_eq(apply_strategies("""
	h....
	3.w..
	}L/L/
	""", s).to_str(), """
	h....
	3.ww.
	}L/L/
	""")
	assert_can_solve("""
	h....
	2.x..
	}L/L/
	""", ["TogetherRowAdvanced", "BasicRow"])
	# empty hole but not too big
	assert_grid_eq(apply_strategies("""
	h......
	3.x....
	}L/L/L/
	""", s).to_str(), """
	h......
	3xx.ww.
	}L/L/L/
	""")
	assert_grid_eq(apply_strategies("""
	h........
	2....x...
	}L/_/L/_/
	""").to_str(), """
	h........
	2x..xx..x
	}L/_/L/_/
	""")
	# Same but for columns
	s = ["TogetherColBasic", "TogetherColAdvanced"]
	assert_can_solve("""
	h3}
	.w.
	.L/
	.w.
	.L/
	""", s)
	assert_grid_eq(apply_strategies("""
	h2}
	..w
	.L/
	...
	.L/
	""", s).to_str(), """
	h2}
	..w
	.L/
	..x
	.L/
	""")
	assert_grid_eq(apply_strategies("""
	h3}
	..w
	.L/
	...
	.L/
	""", s).to_str(), """
	h3}
	..w
	.L/
	.w.
	.L/
	""")

func test_wrong_rule() -> void:
	# This was a bug once
	assert_can_solve("""
	h1...
	3w...
	-L/L.
	""")

func test_separate_rule() -> void:
	var s := ["BasicRow", "SeparateRowBasic", "SeparateRowAdvanced"]
	# Disregard aquarium of size 2
	assert_can_solve("""
	h....
	2....
	-L/_/
	""", s)
	# Put nowater in nearby aquariums because it would be together
	assert_can_solve("""
	h........
	3..w....#
	-L.L/_/_/
	""", s)
	# Can't fill middle or it would be together
	assert_can_solve("""
	h....
	3.w.w
	-L/L/
	""", s)
	assert_can_solve("""
	h......
	4......
	-L.L.L/
	""", s)
	# 3 blocks, must put air in middle
	assert_can_solve("""
	h........
	.........
	-L.L._.L.
	""", s)
	# Must put air and water
	assert_can_solve("""
	h......
	.ww....
	-L.L.L.
	""", s)
	assert_cant_solve("""
	h......
	3#.w.xw
	-L/L/L/
	""", s)
	assert_apply_strategies("""
	h......
	5......
	-L/L/L/
	""", """
	h......
	5w....w
	-L/L/L/
	""", s)
	assert_apply_strategies("""
	h......
	5..w...
	-L/L/L/
	""", """
	h......
	5w.w..w
	-L/L/L/
	""", s)
	s = ["BasicCol", "SeparateColBasic", "SeparateColAdvanced"]
	# Kinda same but for cols
	assert_can_solve("""
	h2-
	...
	.|/
	..#
	.L/
	""", s)
	# Must mark (0, 1) as X
	assert_can_solve("""
	h6-
	...
	.L.
	...
	.|.
	...
	.|.
	.ww
	.L.
	""", s)
	# 3 blocks, must put air in middle, but sometimes it's not possible if the blocks are long
	var single_block := "...\n.L."
	var water_block := ".ww\n.L."
	var double_block := "...\n.|.\n%s" % single_block
	var three_blocks := "h.-\n%s\n%s\n%s"
	assert_can_solve(three_blocks % [single_block, single_block, single_block], s)
	assert_apply_strategies(three_blocks % [double_block, single_block, single_block], three_blocks % ["...\n.|.\n" + water_block, ".xx\n.L.", water_block], s)
	assert_cant_solve(three_blocks % [single_block, double_block, single_block], s)
	assert_cant_solve(three_blocks % [single_block, single_block, double_block], s)
	assert_can_solve(three_blocks % [single_block, double_block, ""], s)
	assert_can_solve(three_blocks % [water_block, single_block, single_block], s)
	assert_cant_solve(three_blocks % [water_block, single_block, double_block], s)
	assert_can_solve(three_blocks % [water_block, double_block, ""], s)


func test_total_waters() -> void:
	var s := ["AllWatersEasy"]
	assert_can_solve("""
	+waters=1
	..
	L.
	""", s)
	assert_can_solve("""
	+waters=1
	..ww
	L.L.
	""", s)
	s += ["AllWatersMedium"]
	assert_can_solve("""
	+waters=1
	....
	L.|.
	....
	L...
	""", s)
	assert_grid_eq(apply_strategies("""
	+waters=3
	....
	L.|.
	....
	L._.
	""", s).to_str(), """
	+waters=3.0
	....
	L.|.
	wwww
	L._.
	""")

func _cmp_waters(a: Array[GridModel.WaterPosition], b: Array[Vector3i]) -> void:
	assert(a.size() == b.size())
	for i in a.size():
		assert(a[i].i == b[i].x)
		assert(a[i].j == b[i].y)
		assert(a[i].loc == b[i].z)

func test_flood_which() -> void:
	var grid_str := """
	....
	|.L.
	%s
	L._/
	"""
	var g := str_grid(grid_str % ["...."])
	_cmp_waters(g.get_cell(0, 0).water_would_flood_which(E.Corner.TopLeft), [Vector3i(0, 0, E.Single), Vector3i(1, 0, E.Single), Vector3i(1, 1, E.TopLeft)])
	_cmp_waters(g.get_cell(0, 0).boat_would_flood_which(), [Vector3i(1, 0, E.Single), Vector3i(1, 1, E.TopLeft)])
	g = str_grid(grid_str % ["www."])
	_cmp_waters(g.get_cell(0, 0).water_would_flood_which(E.Corner.TopLeft), [Vector3i(0, 0, E.Single)])
	_cmp_waters(g.get_cell(0, 0).boat_would_flood_which(), [])

func test_noboat() -> void:
	var grid_str := """
	%s
	L/
	"""
	var g := str_grid(grid_str % "..")
	g.get_cell(0, 0).put_nowater(TopLeft)
	g.get_cell(0, 0).put_noboat(BottomRight)
	assert_grid_eq(g.to_str(), grid_str % "xy")
	g.get_cell(0, 0).put_noboat(TopLeft)
	assert_grid_eq(g.to_str(), grid_str % "zy")
	g.get_cell(0, 0).put_nowater(TopLeft)
	assert_grid_eq(g.to_str(), grid_str % "zy")
	g.get_cell(0, 0).put_nowater(BottomRight)
	assert_grid_eq(g.to_str(), grid_str % "zz")
	g.get_cell(0, 0).remove_content(TopLeft)
	assert_grid_eq(g.to_str(), grid_str % ".z")
	g.undo()
	g.get_cell(0, 0).remove_noboat(TopLeft)
	g.get_cell(0, 0).remove_nowater(BottomRight)
	assert_grid_eq(g.to_str(), grid_str % "xy")
	g = str_grid("""
	..
	|.
	yy
	L.
	""")
	assert(g.get_cell(0, 0).boat_possible())
	assert(g.get_cell(0, 0).water_would_flood_which(TopLeft).map(func(x): return x.to_vec3()) == [Vector3i(0, 0, E.Single), Vector3i(1, 0, E.Single)])
	assert(g.get_cell(0, 0).boat_would_flood_which().map(func(x): return x.to_vec3()) == [Vector3i(1, 0, E.Single)])
	g.get_cell(0, 0).put_noboat(TopLeft)
	# Ignore NoBoat, just like we ignore NoWater when placing water
	assert(g.get_cell(0, 0).boat_possible())

func test_aquariums() -> void:
	var grid_one_aqua := "..\nL."
	assert_cant_solve(grid_one_aqua)
	assert_can_solve("+aqua=1:1\n" + grid_one_aqua)
	assert_can_solve("+aqua=0:0\n" + grid_one_aqua)
	var grid_two_aqua = "...#\nL.L/"
	assert_cant_solve("+aqua=1:1\n" + grid_two_aqua)
	assert_can_solve("+aqua=1:1\n+aqua=0.5:1\n" + grid_two_aqua)
	assert_can_solve("+aqua=1:0\n+aqua=0.5:1\n" + grid_two_aqua)
	assert_can_solve("+aqua=0:0\n" + grid_two_aqua)
	var grid_three_aqua = """
	h....
	2....
	.L.L/
	"""
	assert_cant_solve(grid_three_aqua)
	assert_can_solve("+aqua=1:1\n" + grid_three_aqua)
	assert_can_solve("+aqua=1:0\n" + grid_three_aqua)
	# These are pretty hard
	#assert_can_solve("+aqua=0:2\n" + grid_three_aqua)
	#assert_can_solve("+aqua=0:1\n" + grid_three_aqua)
	assert_can_solve("+aqua=0:1\n.x\nL/")
	# Like level 5x2, uses a bunch of aquarium logics
	assert_can_solve("""
	+aqua=0.5:1
	+aqua=1.0:1
	+aqua=2.0:1
	+aqua=3.0:1
	+aqua=6.0:2
	..............
	|.|.L.|.|╲|...
	..............
	|.|.....|.|...
	..............
	L.L._._.L.L._.
""")
	assert_cant_solve("""
	+aqua=0.0:1
	+waters=3.0
	#.##
	|/L.
	ww#.
	|.L/
	ww..
	L.L.
	""")

func test_propagate_nowater() -> void:
	assert_can_solve("""
	x##.
	|╲|/
	wwww
	L._.
	""")
	assert_cant_solve("""
	+aqua=0.0:1
	h....
	.xxxx
	.|...
	1..xx
	.L/L.
	""")
	assert_apply_strategies("""
	..##......##..
	|.L.|._...L.|.
	..##xx##..##..
	|.L.|.L.|.L.|.
	..##..##..##..
	|.L.|.L.|.L.|.
	......##......
	L._._.L.L._._.
	""", """
	xx##xxxxxx##xx
	|.L.|._...L.|.
	xx##xx##..##..
	|.L.|.L.|.L.|.
	..##..##..##..
	|.L.|.L.|.L.|.
	......##......
	L._._.L.L._._.
	""")

func test_boat_unknown() -> void:
	assert_can_solve("""
	+boats=-1
	B......
	.bb..bb
	}|.|.|.
	.ww..ww
	.L.L.L.
	""")
	assert_can_solve("""
	+boats=-1
	+waters=1
	B....
	.....
	}|.|/
	.....
	.L.L.
	""")
	assert_cant_solve("""
	+boats=-1
	+waters=2
	B....
	.....
	}|.|.
	.....
	.L.L.
	""")
	assert_can_solve("""
	+boats=-1
	+waters=2
	B......
	.......
	-|.|/|.
	.......
	.L.L.L.
	""")
	assert_cant_solve("""
	+boats=-1
	+waters=2
	B........
	.........
	-|.|/|.|.
	.........
	.L.L.L.L.
	""")
	var vertical_boat := """
	...
	.|.
	...
	.L.
	""".strip_edges()
	var vertical_no_boat := """
	...
	.L/
	...
	.L.
	""".strip_edges()
	assert_can_solve("""
	+boats=-1
	+waters=1
	B.}
	%s
	%s
	""" % [vertical_boat, vertical_no_boat])
	assert_cant_solve("""
	+boats=-1
	+waters=1
	B.}
	%s
	%s
	""" % [vertical_boat, vertical_boat])
	assert_can_solve("""
	+boats=-1
	+waters=2
	B.-
	%s
	%s
	%s
	""" % [vertical_boat, vertical_no_boat, vertical_boat])
	assert_cant_solve("""
	+boats=-1
	+waters=2
	B.-
	%s
	%s
	%s
	%s
	""" % [vertical_boat, vertical_no_boat, vertical_boat, vertical_boat])

func test_rotate_mirror() -> void:
	var grid := str_grid("""
	#.
	L/
	..
	|.
	#.
	L╲
	""")
	grid.mirror_horizontal()
	assert_grid_eq(grid.to_str(), """
	.#
	L╲
	..
	|.
	.#
	L/
	""")
	grid.mirror_vertical()
	assert_grid_eq(grid.to_str(), """
	.#
	|╲
	..
	L.
	.#
	L/
	""")
	grid.rotate_clockwise()
	assert_grid_eq(grid.to_str(), """
	#....#
	L╲L._/
	""")
	grid.mirror_horizontal()
	assert_grid_eq(grid.to_str(), """
	#....#
	L╲_.L/
	""")
	grid.mirror_vertical()
	assert_grid_eq(grid.to_str(), """
	#....#
	L/_.L╲
	""")

func test_cell_hints() -> void:
	var g := str_grid("""
	+cellhint=2:2:3.5
	wwwwwwwwww
	|._._._...
	www....www
	|.L/L.L/|.
	ww......ww
	|.L.L.L.|.
	ww..ww..ww
	|.L.L.L.|.
	wwwwwwwwww
	L._._._._.
	""") as GridImpl
	assert(g.get_cell(2, 2).hints().adj_water_count == 3.5)
	assert(g.get_cell(2, 2).hints().adj_water_count_type == E.HintType.Hidden)
	assert(not g.are_hints_satisfied())
	assert(g.count_water_adj(2, 2) == 2.0)
	assert(g.together_waters_adj(2.0, 2, 2) == E.HintType.Separated)
	assert(g.count_water_adj(0, 1) == 4.5)
	g.get_cell(1, 1).put_water(E.Corner.BottomRight)
	assert(not g.are_hints_satisfied())
	g.get_cell(1, 2).put_water(E.Corner.BottomRight)
	assert(g.count_water_adj(2, 2) == 3.5)
	assert(g.are_hints_satisfied())
	assert(g.together_waters_adj(2.0, 2, 2) == E.HintType.Separated)
	g.get_cell(1, 3).put_water(E.Corner.TopLeft)
	assert(g.together_waters_adj(2.0, 2, 2) == E.HintType.Separated)
	assert(not g.are_hints_satisfied())
	g.get_cell(2, 2).put_water(E.Corner.TopLeft)
	assert(g.together_waters_adj(2.0, 2, 2) == E.HintType.Together)
	assert(not g.are_hints_satisfied())
	g.undo()
	g.undo()
	g.get_cell(2, 1).put_water(E.Corner.TopLeft)
	assert(not g.are_hints_satisfied())
	g.get_cell(2, 1).remove_content(E.Corner.TopLeft)
	assert(g.are_hints_satisfied())

	assert_can_solve("""
	+cellhint=1:1:2
	##..
	L.L.
	..##
	L.L.
	""")
	assert_can_solve("""
	+cellhint=1:1:3
	##..
	L.L.
	....
	L._.
	""")
	assert_cant_solve("""
	+cellhint=1:1:2
	##..
	L.L.
	....
	L.L.
	""")
	assert_can_solve("""
	+cellhint=1:1:2
	h....
	.##..
	.L.|.
	2....
	.L.L.
	""")
	assert_can_solve("""
	+cellhint=1:1:1
	h....
	2....
	.L.|.
	.##..
	.L.L.
	""")
	assert_can_solve("""
	+cellhint=1:1:2
	h....
	..#..
	}|╲|.
	.....
	.L.L.
	""")
	# Advanced
	assert_can_solve("""
	+cellhint=1:1:3
	h2.....
	.......
	.L.L._.
	.....##
	.L._.L.
	""")
	assert_can_solve("""
	+cellhint=1:1:1.5
	.#..
	|╲|.
	....
	L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:1.5
	....
	|.L.
	W#..
	L/L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:2.0
	#X..
	|/L.
	....
	L.L.
	""")
	# Using two cellhints
	assert_apply_strategies("""
	+cellhint=1:1:3.0
	+cellhint=1:2:1.0
	WW....
	L.L.L.
	WW....
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:2.5
	+cellhint=2:2:1.0
	....#W
	L.L.L/
	......
	L.L.L/
	......
	L.L.L/
	""")
	# Can't do anything if one is not contained in the other
	assert_apply_strategies("""
	+cellhint=1:1:3.0
	+cellhint=1:2:1.0
	........
	L.L.L.L.
	........
	L.L.L.L.
	""")

func assert_cell_hints_together(s: String, type := E.HintType.Together) -> void:
	var g := str_grid(s)
	assert(g.together_waters_adj(1.0, 1, 1) == type)

func assert_cell_hints_separated(s: String) -> void:
	assert_cell_hints_together(s, E.HintType.Separated)

func test_cell_hints_together() -> void:
	assert_cell_hints_separated("""
	ww..
	L.L.
	..ww
	L.L.
	""")
	assert_cell_hints_together("""
	wwww
	L.L.
	..ww
	L.L.
	""")
	assert_cell_hints_separated("""
	ww.w
	L.L/
	..ww
	L.L.
	""")
	assert_cell_hints_together("""
	wwww
	L.L/
	..ww
	L.L.
	""")
	assert_cell_hints_separated("""
	ww.w
	L.L╲
	wwww
	L.L.
	""")
	assert_cell_hints_together("""
	ww.w
	L.L/
	wwww
	L.L.
	""")
	assert_cell_hints_together("""
	ww....
	L.L.L.
	.www..
	L╲L.L.
	......
	L.L.L.
	""")

func test_cell_hints_together_strat() -> void:
	# Basic
	assert_apply_strategies("""
	+cellhint=1:1:{1.5}
	X#XX##
	L/L/L.
	..##..
	L.L.|.
	.#X#..
	L/L/L.
	""", "", ["BasicTogetherCellHints"])
	assert_apply_strategies("""
	+cellhint=1:1:{?}
	XXX#XX
	L/L/L/
	##.w##
	L.L/L.
	X##XXX
	L/L/L/
	""", "", ["BasicTogetherCellHints"])
	# Advanced together
	assert_apply_strategies("""
	+cellhint=1:1:{3.0}
	##WW..
	L.L.L.
	..WW##
	L.L.L.
	""", "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"])
	assert_apply_strategies("""
	+cellhint=1:1:{2.0}
	##....
	L.L.L.
	....##
	L.L.L.
	""", "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"])
	assert_apply_strategies("""
	+cellhint=1:1:{2.0}
	##WW..
	L.L.L.
	X#..##
	L/L.L.
	""", "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"])
	assert_apply_strategies("""
	+cellhint=1:1:{2.0}
	wW..XX
	L/L.L.
	..XXXX
	L/L.L.
	""", "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"])
	assert_apply_strategies("""
	+cellhint=1:1:{?}
	w.....
	L/L.L.
	......
	L/L.L.
	""", "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"])
	# Doesn't work yet, we need to do a Dijkstra to see cells that are "too far away"
	# It needs to be a dijkstra not BFS if we want to consider aquarium shapes, which would be good
	# assert_apply_strategies("""
	# +cellhint=1:1:{2.0}
	# ##ww..
	# L.L.L.
	# XX..##
	# L.L.L.
	# """, "", ["BasicTogetherCellHints", "TogetherSeparateCellHints"])
	# Advanced separate
	assert_apply_strategies("""
	+cellhint=0:1:-1.0-
	..##W#
	L/L/L/
	""", "", ["TogetherSeparateCellHints"])
	assert_apply_strategies("""
	+cellhint=1:1:-?-
	WWXXWW
	L.|.L.
	XXXXXX
	L._._.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:-3.0-
	WW....
	L.L.L.
	####WW
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=0:1:-2.0-
	WWXXWW
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:-2.0-
	WW##..
	L.L.L.
	####..
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:-1.5-
	XXwXXW
	L.L/./
	####W#
	L.L.L/
	""")
	# Together with shortest path technique
	assert_apply_strategies("""
	+cellhint=0:1:{1.5}
	XXWWW#
	L.L.L/
	XXXXXX
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:{2.0}
	XX..XX
	L.L.L.
	..ww..
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:{3.0}
	ww..XX
	L.L.|.
	....XX
	L.L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:1:{1.5}
	...xXX
	L._/L.
	xxxxxx
	L.L.L.
	X...XX
	L/L.L.
	""")
	assert_apply_strategies("""
	+cellhint=1:2:-?-
	WWWWXX..
	L._.|.|.
	XXXXXXWW
	L._._.L.
	""")

func test_options_sum() -> void:
	assert(OptionsSum.can_be_solved(10., [[1., 9.], [2., 9.]]))
	assert(OptionsSum.can_be_solved(3., [[1., 9.], [2., 9.]]))
	assert(OptionsSum.can_be_solved(11., [[1., 9.], [2., 9.]]))
	assert(OptionsSum.can_be_solved(18., [[1., 9.], [2., 9.]]))
	assert(not OptionsSum.can_be_solved(2., [[1., 9.], [2., 9.]]))
	assert(not OptionsSum.can_be_solved(12., [[1., 9.], [2., 9.]]))
	assert(not OptionsSum.can_be_solved(4., [[1., 9.], [2., 9.]]))
	assert(not OptionsSum.can_be_solved(0., [[1., 9.], [2., 9.]]))
	assert(OptionsSum.can_be_solved(2.0, [[0.], [0., 1.], [0., 1.]]))

func test_steam_details_encode_decode() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 30:
		var f := SteamFlair.new(rng.randi_range(0, 1000), rng.randi_range(0, 12))
		if i == 0:
			f = null
		var det := LeaderboardDetails.new(f)
		var arr := LeaderboardDetails.to_arr(det)
		var new_det := LeaderboardDetails.from_arr(arr)
		if f == null:
			assert(new_det.flair == null)
		else:
			assert(new_det.flair.id == f.id)
			assert(new_det.flair.extra_flairs == f.extra_flairs)
