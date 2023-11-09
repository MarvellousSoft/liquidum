class_name Generator

var rseed: int = randi()

func _init(rseed_: int) -> void:
	rseed = rseed_

func wrand(mx: int, weight: int) -> int:
	var val := randi_range(1, mx)
	for _i in weight:
		val = mini(val, randi_range(1, mx))
	return val

func any_empty(g: Array[Array]) -> Vector2i:
	var i_order := range(g.size())
	i_order.shuffle()
	for i in i_order:
		var j_order = range(g[i].size())
		j_order.shuffle()
		for j in j_order:
			if g[i][j] == 0:
				return Vector2i(i, j)
	return Vector2i(-1, -1)

var dv := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func any_adj(g: Array[Array], cells: Array[Vector2i]) -> Vector2i:
	cells.shuffle()
	for c in cells:
		dv.shuffle()
		for d in dv:
			var e: Vector2i = c + d
			if e.x >= 0 and e.y >= 0 and e.x < g.size() and e.y < g[0].size() and g[e.x][e.y] == 0:
				return e
	return Vector2i(-1, -1)

func generate(n: int, m: int, clear_solution := true) -> GridModel:
	seed(rseed)
	var g: Array[Array] = []
	for i in n:
		g.append([])
		for _j in m:
			g[i].append(0)
	var left := n * m
	var group := 0
	while left > 0:
		group += 1
		var group_size := wrand(left, left / 5) - 1
		left -= 1
		var cells: Array[Vector2i] = [any_empty(g)]
		g[cells[0].x][cells[0].y] = group
		for _i in group_size:
			var c := any_adj(g, cells)
			if c.x == -1:
				break
			g[c.x][c.y] = group
			cells.append(c)
			left -= 1
	var grid := GridImpl.create(n, m)
	for i in n:
		for j in m:
			if j < m - 1 and g[i][j] != g[i][j + 1]:
				grid.get_cell(i, j).put_wall(E.Walls.Right)
			if i < n - 1 and g[i][j] != g[i + 1][j]:
				grid.get_cell(i, j).put_wall(E.Walls.Bottom)
	var i_order := range(n)
	i_order.shuffle()
	for i in i_order:
		var j_order := range(m)
		j_order.shuffle()
		for j in j_order:
			var c := grid.get_cell(i, j)
			if randf() < 0.5:
				if c.water_at(E.Corner.BottomLeft):
					c.remove_water_or_air(E.Corner.BottomLeft)
				else:
					c.put_water(E.Corner.BottomLeft)
	for i in n:
		grid.set_hint_row(i, grid.count_water_row(i))
	for j in m:
		grid.set_hint_col(j, grid.count_water_col(j))
	return grid
