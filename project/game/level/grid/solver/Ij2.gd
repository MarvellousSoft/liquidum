# Helper class to deal with (i, j2) coordinates in the grid
class_name Ij2

static func corner(grid: GridImpl, v: Vector2i) -> E.Corner:
	return grid._pure_cell(v.x, v.y / 2).corners()[v.y & 1]

static func waters(grid: GridImpl, v: Vector2i) -> E.Waters:
	return grid._pure_cell(v.x, v.y / 2).waters()[v.y & 1]

static func size(grid: GridImpl, v: Vector2i) -> float:
	return E.waters_size(Ij2.waters(grid, v))

static func content(grid: GridImpl, v: Vector2i) -> GridImpl.Content:
	var c := grid._pure_cell(v.x, v.y / 2)
	return c.c_left if (v.y & 1) == 0 else c.c_right
