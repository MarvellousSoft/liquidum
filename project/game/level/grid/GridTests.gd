class_name GridTests

const TopLeft := Grid.Corner.TopLeft
const TopRight := Grid.Corner.TopRight
const BottomLeft := Grid.Corner.BottomLeft
const BottomRight := Grid.Corner.BottomRight
const Left := Grid.Side.Left
const Right := Grid.Side.Right
const Top := Grid.Side.Top
const Bottom := Grid.Side.Bottom
const Major := Grid.Diagonal.Major
const Minor := Grid.Diagonal.Minor

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
	# Check diag walls
	assert(!g.get_cell(0, 0).diag_wall_at(Major))
	assert(g.get_cell(0, 1).diag_wall_at(Minor))
	assert(!g.get_cell(0, 1).diag_wall_at(Major))
	assert(g.get_cell(1, 1).diag_wall_at(Major))
	# Check walls
	assert(g.get_cell(0, 0).wall_at(Left))
	assert(!g.get_cell(0, 0).wall_at(Right))
	assert(g.get_cell(0, 0).wall_at(Bottom))
	assert(g.get_cell(0, 0).wall_at(Top))
	assert(!g.get_cell(1, 1).wall_at(Left))
	assert(g.get_cell(1, 1).wall_at(Right))

	assert_grid_eq(simple, g.to_str())
