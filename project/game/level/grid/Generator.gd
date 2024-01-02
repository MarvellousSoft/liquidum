class_name Generator

var rng := RandomNumberGenerator.new()
var diagonals: bool
var boats: bool
var count_vis: float
var type_vis: float

func _init(rseed_: int, diagonals_: bool, boats_: bool) -> void:
	rng.seed = rseed_
	diagonals = diagonals_
	boats = boats_

func wrand(mx: int, weight: int) -> int:
	var val := rng.randi_range(1, mx)
	for _i in weight:
		val = mini(val, rng.randi_range(1, mx))
	return val

func any_empty(g: Array[Array]) -> Vector2i:
	var i_order := range(g.size())
	Global.shuffle(i_order, rng)
	for i in i_order:
		var j_order = range(g[i].size())
		Global.shuffle(j_order, rng)
		for j in j_order:
			if g[i][j] == 0:
				return Vector2i(i, j)
	return Vector2i(-1, -1)

class AdjacencyRule:
	func all_adj(_from: Vector2i, _boats: bool) -> Array[Vector2i]:
		return GridModel.must_be_implemented()

class SquareAdj extends AdjacencyRule:
	const dv := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	func all_adj(from: Vector2i, boats: bool) -> Array[Vector2i]:
		var adj: Array[Vector2i] = []
		adj.assign(dv.map(func(d): return from + d))
		# Hack: make things more vertical when there's boats
		if boats:
			adj.append(from + dv[0])
			adj.append(from + dv[1])
		return adj

class DiagAdj extends AdjacencyRule:
	# Whether each cell was dec diagonal
	var dec_diag: Array[Array]
	func _init(rng: RandomNumberGenerator, n: int, m: int) -> void:
		for i in n:
			var row = []
			for j in m:
				row.append(rng.randf() < 0.5)
			dec_diag.append(row)
	func third_adj(from: Vector2i) -> Vector2i:
		var oj := from.y / 2
		# Connects to top
		if dec_diag[from.x][oj] != ((from.y & 1) == 0):
			return Vector2i(from.x - 1, oj * 2 + int(from.x == 0 or !dec_diag[from.x - 1][oj]))
		else: # connects to bottom
			return Vector2i(from.x + 1, oj * 2 + int(from.x == dec_diag.size() - 1 or dec_diag[from.x + 1][oj]))
	func all_adj(from: Vector2i, boats: bool) -> Array[Vector2i]:
		var adj: Array[Vector2i] = [from + Vector2i(0, -1), from + Vector2i(0, 1), third_adj(from)]
		# Hack: make things more vertical when there's boats
		if boats:
			adj.append(adj.back())
		return adj

func pop_random(arr: Array[Vector2i]) -> Vector2i:
	if arr.is_empty():
		return Vector2i(-1, -1)
	var i := rng.randi_range(0, arr.size() - 1)
	var val := arr[i]
	arr[i] = arr.back()
	arr.pop_back()
	return val

func _gen_grid_groups(n: int, m: int, adj_rule: AdjacencyRule) -> Array[Array]:
	var min_aqs: int
	if diagonals:
		m *= 2
		min_aqs = (n * m) / 5
	else:
		min_aqs = int((n * m) / 2.5)
	var g: Array[Array] = []
	for i in n:
		g.append([])
		for _j in m:
			g[i].append(0)
	var left := n * m
	var group := 0
	# Break groups into similar sizes, this uses the "sticks and rocks" technique
	var group_sizes: Array[int] = [left - 1]
	for group_i in rng.randi_range(min_aqs, (n * m) / 2):
		var s := rng.randi_range(0, left - 2 - group_i)
		for j in (group_i + 1):
			if s < group_sizes[j]:
				var rest := group_sizes[j] - s
				group_sizes[j] = s
				group_sizes.append(rest - 1)
				break
			s -= group_sizes[j]
	var all_empty: Array[Vector2i] = []
	for i in n:
		for j in m:
			all_empty.append(Vector2i(i, j))
	Global.shuffle(all_empty, rng)
	while left > 0:
		group += 1
		var group_size: int = group_sizes.pop_back() + 1
		if group_sizes.is_empty():
			group_sizes.push_back(5)
		left -= 1
		while g[all_empty.back().x][all_empty.back().y] != 0:
			all_empty.pop_back()
		var cells: Array[Vector2i] = [all_empty.pop_back()]
		g[cells[0].x][cells[0].y] = group
		var all_adj: Array[Vector2i] = adj_rule.all_adj(cells[0], boats)
		for _i in group_size:
			var c := pop_random(all_adj)
			while c != Vector2i(-1, -1) and (c.x < 0 or c.x >= n or c.y < 0 or c.y >= m or g[c.x][c.y] != 0):
				c = pop_random(all_adj)
			if c.x == -1:
				break
			g[c.x][c.y] = group
			cells.append(c)
			all_adj.append_array(adj_rule.all_adj(c, boats))
			left -= 1
	return g

func _all_cells(grid: GridModel) -> Array[Vector2i]:
	var all_cells: Array[Vector2i] = []
	for i in grid.rows():
		for j in grid.cols():
			all_cells.append(Vector2i(i, j))
	return all_cells

func randomize_boats(grid: GridModel) -> void:
	var all_cells := _all_cells(grid)
	Global.shuffle(all_cells, rng)
	for idx in all_cells:
		if not SolverModel._boat_possible(grid, idx.x, idx.y):
			continue
		var c := grid.get_cell(idx.x, idx.y)
		if rng.randf() < 0.5:
			if not c.put_boat(true):
				push_error("Boat placing should succeed")


func randomize_water(grid: GridModel, flush_undo := true) -> void:
	if flush_undo:
		grid.push_empty_undo()
	var water_wanted: float = int(grid.rows() * grid.cols() * rng.randf_range(0.2, 0.75)) - grid.count_waters()
	var all_cells := _all_cells(grid)
	while not all_cells.is_empty():
		var idx: Vector2i = pop_random(all_cells)
		var corners := [E.Corner.TopLeft]
		var c := grid.get_cell(idx.x, idx.y)
		if c.wall_at(E.Walls.IncDiag):
			corners = [E.Corner.TopLeft, E.Corner.BottomRight]
		elif c.wall_at(E.Walls.DecDiag):
			corners = [E.Corner.TopRight, E.Corner.BottomLeft]
		for corner in corners:
			if c.nothing_at(corner):
				water_wanted -= c.put_water(corner, false)
				if water_wanted <= 0:
					return

static func randomize_aquarium_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var all_aqs := grid.all_aquarium_counts()
	# Add some small sizes that may be 0
	all_aqs[0.0] = all_aqs.get(0.0, 0)
	var any_diags := range(grid.rows()).any(func(i): return range(grid.cols()).any(func(j): return grid.get_cell(i, j).cell_type() != E.Single))
	if any_diags:
		all_aqs[0.5] = all_aqs.get(0.5, 0)
	all_aqs[1.0] = all_aqs.get(1.0, 0)
	var expected := grid.grid_hints().expected_aquariums
	var szs := all_aqs.keys()
	Global.shuffle(szs, rng)
	szs.resize(rng.randi_range(1, maxi(1, szs.size() - 2)))
	for sz in szs:
		expected[sz] = all_aqs[sz]

func generate(n: int, m: int) -> GridModel:
	# Reset rng
	rng.seed = rng.seed
	var adj_rule: AdjacencyRule
	if diagonals:
		adj_rule = DiagAdj.new(rng, n, m)
	else:
		adj_rule = SquareAdj.new()
	
	var g := _gen_grid_groups(n, m, adj_rule)
	var grid := GridImpl.empty_editor(n, m)
	# Let's just update once in the end
	grid.set_auto_update_hints(false)
	for i in n:
		for j in m:
			if diagonals:
				var diag_adj: DiagAdj = adj_rule as DiagAdj
				if j < m - 1 and g[i][2 * j + 1] != g[i][2 * j + 2]:
					grid.get_cell(i, j).put_wall(E.Walls.Right, false, true)
				var from := Vector2i(i, 2 * j) if diag_adj.dec_diag[i][j] else Vector2i(i, 2 * j + 1)
				var bottom := diag_adj.third_adj(from)
				if i < n - 1 and g[from.x][from.y] != g[bottom.x][bottom.y]:
					grid.get_cell(i, j).put_wall(E.Walls.Bottom, false, true)
				if g[i][2 * j] != g[i][2 * j + 1]:
					grid.get_cell(i, j).put_wall(E.Walls.DecDiag if diag_adj.dec_diag[i][j] else E.Walls.IncDiag, false, true)
			else:
				if j < m - 1 and g[i][j] != g[i][j + 1]:
					grid.get_cell(i, j).put_wall(E.Walls.Right, false, true)
				if i < n - 1 and g[i][j] != g[i + 1][j]:
					grid.get_cell(i, j).put_wall(E.Walls.Bottom, false, true)
	if boats:
		randomize_boats(grid)
	randomize_water(grid, false)
	# Necessary because we did unsafe updates
	grid.set_auto_update_hints(true)
	return grid
