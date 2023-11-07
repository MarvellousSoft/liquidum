class_name GridImpl
extends Grid

static func create(rows_: int, cols_: int) -> Grid:
	return GridImpl.new(rows_, cols_)

# Everything below is implementation details about grids.

var n: int
var m: int
# NxM Array[Array[PureCell]] but GDscript doesn't support it
var pure_cells: Array[Array]
var hint_rows: Array[int]
var hint_cols: Array[int]
# (N-1)xM Array[Array[bool]]
var wall_down: Array[Array]
# Nx(M-1) Array[Array[bool]]
var wall_right: Array[Array]

func _init(n_: int, m_: int) -> void:
	self.n = n_
	self.m = m_
	for i in n:
		var row: Array[PureCell] = []
		var row_down: Array[bool] = []
		var row_right: Array[bool] = []
		for j in m:
			row.append(PureCell.empty())
			row_down.append(false)
			if j < m - 1:
				row_right.append(false)
		pure_cells.append(row)
		wall_right.append(row_right)
		if i < n - 1:
			wall_down.append(row_down)
	for i in n:
		hint_rows.append(-1)
	for j in m:
		hint_cols.append(-1)

class PureCell:
	# By default, uses major diagonal \, if inverted uses minor /
	var inverted: bool
	var water_left: bool
	var water_right: bool
	var diag_wall: bool
	static func empty() -> PureCell:
		return PureCell.new()
	func water_full() -> bool:
		return water_left and water_right
	func water_at(corner: Grid.Corner) -> bool:
		if water_full():
			return true
		match corner:
			Corner.TopLeft:
				return inverted and water_left
			Corner.TopRight:
				return !inverted and water_right
			Corner.BottomLeft:
				return !inverted and water_left
			Corner.BottomRight:
				return inverted and water_right
		assert(false, "Invalid corner")
		return false
	func diag_wall_at(diag: Grid.Diagonal) -> bool:
		match diag:
			Diagonal.Major: # \
				return !inverted and diag_wall
			Diagonal.Minor:
				return inverted and diag_wall
		assert(false, "Invalid diagonal")
		return false


class CellWithLoc extends Grid.Cell:
	var pure: PureCell
	var i: int
	var j: int
	var grid: GridImpl
	func _init(pure_: PureCell, i_: int, j_: int, grid_: GridImpl) -> void:
		self.pure = pure_
		self.i = i_
		self.j = j_
		self.grid = grid_
	func water_full() -> bool:
		return pure.water_full()
	func water_at(corner: Grid.Corner) -> bool:
		return pure.water_at(corner)
	func wall_at(side: Grid.Side) -> bool:
		return grid.wall_at(i, j, side)
	func diag_wall_at(diag: Grid.Diagonal) -> bool:
		return pure.diag_wall_at(diag)

func rows() -> int:
	return n

func cols() -> int:
	return m

func _pure_cell(i: int, j: int) -> PureCell:
	return pure_cells[i][j]

func get_cell(i: int, j: int) -> Cell:
	return CellWithLoc.new(_pure_cell(i, j), i, j, self)

func hint_row(i: int) -> float:
	return hint_rows[i]

func hint_col(j: int) -> float:
	return hint_cols[j]

func wall_at(i: int, j: int, side: Grid.Side) -> bool:
	match side:
		Side.Left:
			return _has_wall_left(i, j)
		Side.Right:
			return _has_wall_right(i, j)
		Side.Top:
			return _has_wall_up(i, j)
		Side.Bottom:
			return _has_wall_down(i, j)
	assert(false, "Invalid side")
	return false

func _has_wall_down(i: int, j: int) -> bool:
	return i == n - 1 or wall_down[i][j]

func _has_wall_up(i: int, j: int) -> bool:
	return i == 0 or _has_wall_down(i - 1, j)

func _has_wall_right(i: int, j: int) -> bool:
	return j == m - 1 or wall_right[i][j]

func _has_wall_left(i: int, j: int) -> bool:
	return j == 0 or _has_wall_right(i, j - 1)

func load_from_str(s: String) -> void:
	pass

func to_str() -> String:
	return ""
