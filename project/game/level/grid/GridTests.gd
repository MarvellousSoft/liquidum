class_name GridTests

const TopLeft := GridModel.Corner.TopLeft
const TopRight := GridModel.Corner.TopRight
const BottomLeft := GridModel.Corner.BottomLeft
const BottomRight := GridModel.Corner.BottomRight
const Left := GridModel.Side.Left
const Right := GridModel.Side.Right
const Top := GridModel.Side.Top
const Bottom := GridModel.Side.Bottom
const Dec := GridModel.Diagonal.Dec
const Inc := GridModel.Diagonal.Inc

func run_all_tests() -> void:
	for method in get_method_list():
		var name: String = method["name"]
		if name.begins_with("test_"):
			print("Running %s" % name)
			call(name)

func assert_grid_eq(a: String, b: String) -> void:
	a = a.dedent().strip_edges()
	b = b.dedent().strip_edges()
	if a != b:
		print("Grids differ:\n%s\n\n%s" % [a, b])
		assert(a == b)


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
	...w
	L._╲
	"""
	var g := GridImpl.create(2, 2)
	assert(!g.get_cell(0, 0).water_full())
	g.load_from_str(simple)
	# Check waters make sense
	assert(g.get_cell(0, 0).water_full())
	for corner in [BottomLeft, BottomRight, TopLeft, TopRight]:
		assert(g.get_cell(0, 0).water_at(corner))
	assert(g.get_cell(0, 1).water_at(TopLeft))
	assert(!g.get_cell(0, 1).water_at(BottomRight))
	assert(g.get_cell(1, 1).water_at(TopRight))
	assert(!g.get_cell(1, 1).water_at(BottomLeft))
	# Check air
	assert(!g.get_cell(0, 0).air_at(TopLeft))
	assert(!g.get_cell(0, 1).air_at(TopLeft))
	assert(g.get_cell(0, 1).air_at(BottomRight))
	assert(!g.get_cell(1, 0).air_at(BottomLeft) and !g.get_cell(1, 0).water_at(BottomRight))
	assert(g.is_flooded())
	# Check diag walls
	assert(!g.get_cell(0, 0).diag_wall_at(Dec))
	assert(g.get_cell(0, 1).diag_wall_at(Inc))
	assert(!g.get_cell(0, 1).diag_wall_at(Dec))
	assert(g.get_cell(1, 1).diag_wall_at(Dec))
	# Check walls
	assert(g.get_cell(0, 0).wall_at(Left))
	assert(!g.get_cell(0, 0).wall_at(Right))
	assert(g.get_cell(0, 0).wall_at(Bottom))
	assert(g.get_cell(0, 0).wall_at(Top))
	assert(!g.get_cell(1, 1).wall_at(Left))
	assert(g.get_cell(1, 1).wall_at(Right))

	assert_grid_eq(simple, g.to_str())

func test_is_flooded() -> void:
	assert(str_grid("..\n..").is_flooded())
	assert(!str_grid("w.\n..").is_flooded())
	assert(!str_grid(".w\n..").is_flooded())
	assert(str_grid("ww\n..").is_flooded())
	assert(str_grid("w.\n.╲").is_flooded())
	assert(str_grid("w.\n./").is_flooded())
	assert(!str_grid("""
	ww..
	L._/
	""").is_flooded())
	assert(str_grid("""
	ww..
	L.L/
	""").is_flooded())
	assert(!str_grid("""
	..w.
	L._/
	""").is_flooded())
	# Tricky case with a "cave" on top, where gravity should carry water to the other side
	#assert(!str_grid("""
	#w..w
	#|╲./
	#wwww
	#L._.
	#""").is_flooded())

func test_put_water_one_cell() -> void:
	var g := str_grid("..\n..")
	g.get_cell(0, 0).put_water(BottomRight)
	assert(g.is_flooded())
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
......
L._╲_.
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
...www
L._╲_.
	""")
	# Test flooding up through "caves"
	g.undo()
	g.get_cell(1, 1).put_water(BottomRight)
	assert(g.get_cell(1, 0).water_at(BottomLeft))
	# Other direction
	g.undo()
	assert(!g.get_cell(1, 1).water_at(BottomRight))
	g.get_cell(1, 0).put_water(BottomLeft)
	assert(g.get_cell(1, 1).water_at(BottomRight))
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
www...
L._╲_.
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
......
L._╲_.
	""")
	assert(g.hint_col(0) == -1.)
	g.set_hint_col(0, 1.5)
	assert(g.hint_col(0) == 1.5)
	g.set_hint_row(1, 1.)
	assert(g.are_hints_satisfied())
	g.set_hint_col(2, 0.5)
	assert(g.are_hints_satisfied())
	g.set_hint_row(0, 0.5)
	assert(!g.are_hints_satisfied())
