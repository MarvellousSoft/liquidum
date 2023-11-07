class_name GridImpl
extends GridModel

static func create(rows_: int, cols_: int) -> GridModel:
	return GridImpl.new(rows_, cols_)

# Everything below is implementation details about grids.

const TopLeft := GridModel.Corner.TopLeft
const TopRight := GridModel.Corner.TopRight
const BottomLeft := GridModel.Corner.BottomLeft
const BottomRight := GridModel.Corner.BottomRight

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
# Optimization for DFSs
var last_seen := 0
# List of changes to undo and redo
var undo_stack: Array[Changes] = []
var redo_stack: Array[Changes] = []

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

enum Content { Nothing, Water, Air }

class PureCell:
	# By default, uses inc diagonal /, if inverted uses dec \
	var inverted: bool
	var c_left := Content.Nothing
	var c_right := Content.Nothing
	var diag_wall: bool
	# Last seen by a dfs
	var last_seen := 0
	static func empty() -> PureCell:
		return PureCell.new()
	func _content_at(corner: GridModel.Corner) -> Content:
		if c_left == c_right:
			return c_left
		match corner:
			Corner.TopLeft:
				return c_left if !inverted else Content.Nothing
			Corner.TopRight:
				return c_right if inverted else Content.Nothing
			Corner.BottomLeft:
				return c_left if inverted else Content.Nothing
			Corner.BottomRight:
				return c_right if !inverted else Content.Nothing
		assert(false, "Invalid corner")
		return Content.Nothing
	func water_full() -> bool:
		return c_left == Content.Water and c_right == Content.Water
	func water_at(corner: GridModel.Corner) -> bool:
		return _content_at(corner) == Content.Water
	func air_full() -> bool:
		return c_left == Content.Air and c_right == Content.Air
	func air_at(corner: GridModel.Corner) -> bool:
		return _content_at(corner) == Content.Air
	func diag_wall_at(diag: GridModel.Diagonal) -> bool:
		match diag:
			Diagonal.Dec: # \
				return inverted and diag_wall
			Diagonal.Inc: # /
				return !inverted and diag_wall
		assert(false, "Invalid diagonal")
		return false
	func put_content(corner: GridModel.Corner, content: Content) -> bool:
		var prev_left := c_left
		var prev_right := c_right
		if corner == TopLeft or corner == BottomLeft:
			if diag_wall:
				assert(!inverted if corner == TopLeft else inverted, "Invalid corner")
			else:
				c_right = content
			c_left = content
		else:
			if diag_wall:
				assert(!inverted if corner == BottomRight else inverted, "Invalid corner")
			else:
				c_left = content
			c_right = content
		return prev_left != c_left or prev_right != c_right
	func put_water(corner: GridModel.Corner) -> bool:
		return put_content(corner, Content.Water)
	func put_air(corner: GridModel.Corner) -> bool:
		return put_content(corner, Content.Air)
	func clone() -> PureCell:
		var cell := PureCell.empty()
		cell.c_left = c_left
		cell.c_right = c_right
		cell.inverted = inverted
		cell.diag_wall = diag_wall
		# last_seen doesn't need to be copied
		return cell

class Change:
	var i: int
	var j: int
	var prev_cell: PureCell
	func _init(i_: int, j_: int, prev_cell_: PureCell) -> void:
		i = i_
		j = j_
		prev_cell = prev_cell_

class Changes:
	var changes: Array[Change]
	func _init(changes_: Array[Change]) -> void:
		changes = changes_

class CellWithLoc extends GridModel.CellModel:
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
	func water_at(corner: GridModel.Corner) -> bool:
		return pure.water_at(corner)
	func air_full() -> bool:
		return pure.air_full()
	func air_at(corner: GridModel.Corner) -> bool:
		return pure.air_at(corner)
	func wall_at(side: GridModel.Side) -> bool:
		return grid.wall_at(i, j, side)
	func diag_wall_at(diag: GridModel.Diagonal) -> bool:
		return pure.diag_wall_at(diag)
	func put_water(corner: GridModel.Corner) -> void:
		var changes: Array[Change] = [Change.new(i, j, pure.clone())]
		if pure.put_water(corner):
			changes.append_array(grid._flood_from(i, j, corner))
			grid._push_undo_changes(changes)
	func put_air(corner: GridModel.Corner) -> void:
		var changes: Array[Change] = [Change.new(i, j, pure.clone())]
		if pure.put_air(corner):
			changes.append_array(grid._flood_from(i, j, corner))
			grid._push_undo_changes(changes)

func rows() -> int:
	return n

func cols() -> int:
	return m

func _pure_cell(i: int, j: int) -> PureCell:
	return pure_cells[i][j]

func get_cell(i: int, j: int) -> CellModel:
	return CellWithLoc.new(_pure_cell(i, j), i, j, self)

func hint_row(i: int) -> float:
	return hint_rows[i]

func hint_col(j: int) -> float:
	return hint_cols[j]

func wall_at(i: int, j: int, side: GridModel.Side) -> bool:
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

func _validate(chr: String, possible: String) -> String:
	assert(possible.contains(chr), "'%s' is not one of '%s'" % [chr, possible])
	return chr

func _str_content(chr: String) -> Content:
	match chr:
		'.':
			return Content.Nothing
		'w':
			return Content.Water
		'x':
			return Content.Air
	assert(false, "Unknown content")
	return Content.Nothing

func _content_str(c: Content) -> String:
	match c:
		Content.Nothing:
			return '.'
		Content.Water:
			return 'w'
		Content.Air:
			return 'x'
	assert(false, "Unknown content")
	return '?'

func load_from_str(s: String) -> void:
	var lines := s.dedent().strip_edges().split('\n', false)
	assert(lines.size() == 2 * n, "Invalid number of rows")
	for i in n:
		for j in m:
			var c1: String = _validate(lines[2 * i][2 * j], '.wx')
			var c2: String = _validate(lines[2 * i][2 * j + 1], '.wx')
			var c3: String = _validate(lines[2 * i + 1][2 * j], '.|_L')
			var c4: String = _validate(lines[2 * i + 1][2 * j + 1], '.╲/')
			var cell := _pure_cell(i, j)
			cell.c_left = _str_content(c1)
			cell.c_right = _str_content(c2)
			cell.inverted = (c4 == '╲')
			cell.diag_wall = (c4 == '/' or c4 == '╲')
			if i < n - 1:
				wall_down[i][j] = (c3 == '_' or c3 == 'L')
			if j > 0:
				wall_right[i][j - 1] = (c3 == '|' or c3 == 'L')

func to_str() -> String:
	var builder := PackedStringArray()
	for i in n:
		for j in m:
			var cell := _pure_cell(i, j)
			builder.append(_content_str(cell.c_left))
			builder.append(_content_str(cell.c_right))
		builder.append("\n")
		for j in m:
			var left := _has_wall_left(i, j)
			var down := _has_wall_down(i, j)
			if left:
				builder.append("L" if down else "|")
			else:
				builder.append("_" if down else ".")
			var cell := _pure_cell(i, j)
			if cell.diag_wall:
				builder.append("╲" if cell.inverted else "/")
			else:
				builder.append(".")
		builder.append("\n")
	return "".join(builder)

func is_flooded() -> bool:
	const Air := Content.Air
	const Nothing := Content.Nothing
	const Water := Content.Water
	for i in n:
		for j in m:
			var cell := _pure_cell(i, j)
			# No wall but different contents
			if !cell.diag_wall and cell.c_left != cell.c_right:
				return false
			# Should content escape left?
			if !_has_wall_left(i, j) and cell.c_left != Nothing:
				if _pure_cell(i, j - 1).c_right != cell.c_left:
					return false
			# Should content escape right
			if !_has_wall_right(i, j) and cell.c_right != Nothing:
				if _pure_cell(i, j + 1).c_left != cell.c_right:
					return false
			# Should air escape up
			if !_has_wall_up(i, j) and (cell._content_at(Corner.TopLeft) == Air or cell._content_at(Corner.TopRight) == Air):
				var up := _pure_cell(i - 1, j)
				if up._content_at(Corner.BottomLeft) != Air and up._content_at(Corner.BottomRight) != Air:
					return false
			# Should water escape down
			if !_has_wall_down(i, j) and (cell._content_at(Corner.BottomLeft) == Water or cell._content_at(Corner.BottomRight) == Water):
				var down := _pure_cell(i + 1, j)
				if down._content_at(Corner.TopLeft) != Water and down._content_at(Corner.TopRight) != Water:
					return false
			# TODO: Water up "cave"
	return true

func _undo_impl(undos: Array[Changes], redos: Array[Changes]) -> bool:
	if undos.is_empty():
		return false
	var changes: Array[Change] = undos.pop_back().changes
	for c in changes:
		var now_cell: PureCell = pure_cells[c.i][c.j]
		pure_cells[c.i][c.j] = c.prev_cell
		# Maybe clone isn't necessary, but let's be safe
		c.prev_cell = now_cell.clone()
	# changes is now the changes to redo the undo
	redos.push_back(Changes.new(changes))
	return true

func undo() -> bool:
	return _undo_impl(undo_stack, redo_stack)

func redo() -> bool:
	# Beautifully, redo works exactly the same as undo
	return _undo_impl(redo_stack, undo_stack)

func _push_undo_changes(changes: Array[Change]) -> void:
	redo_stack.clear()
	undo_stack.push_back(Changes.new(changes))

func _flood_from(i: int, j: int, corner: GridModel.Corner) -> Array[Change]:
	# "Clears" DFS lazily so we make sure we don't visit the same thing twice
	last_seen += 1
	if _pure_cell(i, j).water_at(corner):
		var dfs := WaterDfs.new(self, i)
		dfs.flood(i, j, corner)
		return dfs.changes
	elif _pure_cell(i, j).air_at(corner):
		# TODO
		return []
	return []

class WaterDfs:
	var grid: GridImpl
	# Water can go up to level min_i because of physics
	var min_i: int
	var changes: Array[Change] = []
	func _init(grid_: GridImpl, min_i_: int) -> void:
		grid = grid_
		min_i = min_i_
	func flood(i: int, j: int, corner: GridModel.Corner) -> void:
		var cell := grid._pure_cell(i, j)
		if cell.last_seen == grid.last_seen:
			return
		cell.last_seen = grid.last_seen
		# Try to flood the same cell
		var prev_cell := cell.clone()
		if cell.put_water(corner):
			changes.append(Change.new(i, j, prev_cell))
		var is_left := (corner == TopLeft or corner == BottomLeft)
		var is_top := (corner == TopLeft or corner == TopRight)
		# Try to flood left
		if !grid._has_wall_left(i, j) and !(cell.diag_wall and !is_left):
			flood(i, j - 1, TopRight if grid._pure_cell(i, j - 1).inverted else BottomRight)
		# Try to flood right
		if !grid._has_wall_right(i, j) and !(cell.diag_wall and is_left):
			flood(i, j + 1, BottomLeft if grid._pure_cell(i, j + 1).inverted else TopLeft)
		# Try to flood down
		if !grid._has_wall_down(i, j) and !(cell.diag_wall and is_top):
			flood(i + 1, j, TopRight if grid._pure_cell(i + 1, j).inverted else TopLeft)
		# Try to flood up, if gravity helps
		if !grid._has_wall_up(i, j) and !(cell.diag_wall and !is_top) and i - 1 >= min_i:
			flood(i - 1, j, BottomLeft if grid._pure_cell(i - 1, j).inverted else BottomRight)
