class_name Generator

var rng := RandomNumberGenerator.new()

func _init(rseed_: int) -> void:
	rng.seed = rseed_

func _shuffle(a: Array) -> void:
	for i in a.size():
		var j := rng.randi_range(i, a.size() - 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

func wrand(mx: int, weight: int) -> int:
	var val := rng.randi_range(1, mx)
	for _i in weight:
		val = mini(val, rng.randi_range(1, mx))
	return val

func any_empty(g: Array[Array]) -> Vector2i:
	var i_order := range(g.size())
	_shuffle(i_order)
	for i in i_order:
		var j_order = range(g[i].size())
		_shuffle(j_order)
		for j in j_order:
			if g[i][j] == 0:
				return Vector2i(i, j)
	return Vector2i(-1, -1)

class AdjacencyRule:
	func all_adj(_from: Vector2i) -> Array[Vector2i]:
		return GridModel.must_be_implemented()

class SquareAdj extends AdjacencyRule:
	const dv := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	func all_adj(from: Vector2i) -> Array[Vector2i]:
		var adj: Array[Vector2i] = []
		adj.assign(dv.map(func(d): return from + d))
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
	func all_adj(from: Vector2i) -> Array[Vector2i]:
		return [from + Vector2i(0, -1), from + Vector2i(0, 1), third_adj(from)]

func any_adj(g: Array[Array], cells: Array[Vector2i], adj_rule: AdjacencyRule) -> Vector2i:
	_shuffle(cells)
	for c in cells:
		var adj := adj_rule.all_adj(c)
		# Slight hack: Add the other side of the same cell to make diagonals less common
		adj.append(Vector2i(c.x, c.y ^ 1))
		adj.append(Vector2i(c.x, c.y ^ 1))
		_shuffle(adj)
		for e in adj:
			if e.x >= 0 and e.y >= 0 and e.x < g.size() and e.y < g[0].size() and g[e.x][e.y] == 0:
				return e
	return Vector2i(-1, -1)

func _gen_grid_groups(n: int, m: int, adj_rule: AdjacencyRule) -> Array[Array]:
	var g: Array[Array] = []
	for i in n:
		g.append([])
		for _j in m:
			g[i].append(0)
	var left := n * m
	var group := 0
	# Break groups into similar sizes, this uses the "sticks and rocks" technique
	var group_sizes: Array[int] = [left - 1]
	for group_i in (n * m) / 2:
		var s := rng.randi_range(0, left - 2 - group_i)
		for j in (group_i + 1):
			if s < group_sizes[j]:
				var rest := group_sizes[j] - s
				group_sizes[j] = s
				group_sizes.append(rest - 1)
				break
			s -= group_sizes[j]
	while left > 0:
		group += 1
		var group_size: int = group_sizes.pop_back() + 1
		if group_sizes.is_empty():
			group_sizes.push_back(2)
		left -= 1
		var cells: Array[Vector2i] = [any_empty(g)]
		g[cells[0].x][cells[0].y] = group
		for _i in group_size:
			var c := any_adj(g, cells, adj_rule)
			if c.x == -1:
				break
			g[c.x][c.y] = group
			cells.append(c)
			left -= 1
	return g

func randomize_water(grid: GridModel) -> void:
	var i_order := range(grid.rows())
	_shuffle(i_order)
	for i in i_order:
		var j_order := range(grid.cols())
		_shuffle(j_order)
		for j in j_order:
			var corners := [E.Corner.TopLeft]
			var c := grid.get_cell(i, j)
			if c.wall_at(E.Walls.IncDiag):
				corners = [E.Corner.TopLeft, E.Corner.BottomRight]
			elif c.wall_at(E.Walls.DecDiag):
				corners = [E.Corner.TopRight, E.Corner.BottomLeft]
			for corner in corners:
				if rng.randf() < 0.5:
					if c.water_at(corner):
						c.remove_content(corner)
					elif c.nothing_at(corner):
						c.put_water(corner)

func generate(n: int, m: int, diagonals := true) -> GridModel:
	# Reset rng
	rng.seed = rng.seed
	var adj_rule: AdjacencyRule
	if diagonals:
		adj_rule = DiagAdj.new(rng, n, m)
	else:
		adj_rule = SquareAdj.new()
	var g := _gen_grid_groups(n, 2 * m if diagonals else m, adj_rule)
	var grid := GridImpl.empty_editor(n, m)
	for i in n:
		for j in m:
			if diagonals:
				var diag_adj: DiagAdj = adj_rule as DiagAdj
				if j < m - 1 and g[i][2 * j + 1] != g[i][2 * j + 2]:
					grid.get_cell(i, j).put_wall(E.Walls.Right)
				var from := Vector2i(i, 2 * j) if diag_adj.dec_diag[i][j] else Vector2i(i, 2 * j + 1)
				var bottom := diag_adj.third_adj(from)
				if i < n - 1 and g[from.x][from.y] != g[bottom.x][bottom.y]:
					grid.get_cell(i, j).put_wall(E.Walls.Bottom)
				if g[i][2 * j] != g[i][2 * j + 1]:
					grid.get_cell(i, j).put_wall(E.Walls.DecDiag if diag_adj.dec_diag[i][j] else E.Walls.IncDiag)
			else:
				if j < m - 1 and g[i][j] != g[i][j + 1]:
					grid.get_cell(i, j).put_wall(E.Walls.Right)
				if i < n - 1 and g[i][j] != g[i + 1][j]:
					grid.get_cell(i, j).put_wall(E.Walls.Bottom)
	randomize_water(grid)
	return grid
