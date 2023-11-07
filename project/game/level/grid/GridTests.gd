class_name GridTests

const Corner := Grid.Corner
const Side := Grid.Side
const Diag := Grid.Diagonal
const TopLeft = Grid.Corner.TopLeft

func run_all_tests() -> void:
	for method in get_method_list():
		var name: String = method["name"]
		if name.begins_with("test_"):
			print("Running test %s" % name)
			call(name)

func assert_grid_eq(a: String, b: String) -> void:
	a = a.dedent().strip_edges()
	b = b.dedent().strip_edges()
	if a != b:
		print("Grids differ:\n%s\n---\n%s" % [a, b])
		assert(a == b)

func test_simple() -> void:
	var simple := """
	L../
	...w
	L._╲
	"""
	var g := GridImpl.create(2, 2)
	assert(!g.get_cell(0, 0).water_full())
	g.load_from_str(simple)
	# Check waters make sense
	assert(g.get_cell(0, 0).water_full())
	for corner in [Corner.BottomLeft, Corner.BottomRight, Corner.TopLeft, Corner.TopRight]:
		assert(g.get_cell(0, 0).water_at(corner))
	assert(g.get_cell(0, 1).water_at(TopLeft))
	assert(!g.get_cell(0, 1).water_at(Corner.BottomRight))
	assert(g.get_cell(1, 1).water_at(Corner.TopRight))
	assert(!g.get_cell(1, 1).water_at(Corner.BottomLeft))
	# Check diag walls
	assert(!g.get_cell(0, 0).diag_wall_at(Diag.Major))
	assert(g.get_cell(0, 1).diag_wall_at(Diag.Minor))
	assert(!g.get_cell(0, 1).diag_wall_at(Diag.Major))
	assert(g.get_cell(1, 1).diag_wall_at(Diag.Major))
	# Check walls
	assert(g.get_cell(0, 0).wall_at(Side.Left))
	assert(!g.get_cell(0, 0).wall_at(Side.Right))
	assert(g.get_cell(0, 0).wall_at(Side.Bottom))
	assert(g.get_cell(0, 0).wall_at(Side.Top))
	assert(!g.get_cell(1, 1).wall_at(Side.Left))
	assert(g.get_cell(1, 1).wall_at(Side.Right))

	assert_grid_eq(simple, g.to_str())
