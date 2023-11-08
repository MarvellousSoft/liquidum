class_name GridImpl
extends GridModel

static func create(rows_: int, cols_: int) -> GridModel:
	return GridImpl.new(rows_, cols_)

static func from_str(s: String) -> GridModel:
	s = s.dedent().strip_edges()
	# Integer division round down makes this work even with hints
	var rows_ := (s.count('\n') + 1) / 2
	var cols_ := s.find('\n') / 2
	var g := GridImpl.new(rows_, cols_)
	g.load_from_str(s)
	return g

# Everything below is implementation details about grids.

const TopLeft := E.Corner.TopLeft
const TopRight := E.Corner.TopRight
const BottomLeft := E.Corner.BottomLeft
const BottomRight := E.Corner.BottomRight

var n: int
var m: int
# NxM Array[Array[PureCell]] but GDscript doesn't support it
var pure_cells: Array[Array]
var hint_rows: Array[float]
var hint_cols: Array[float]
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
		hint_rows.append(-1.)
	for j in m:
		hint_cols.append(-1.)

enum Content { Nothing, Water, Air, Block }

class PureCell:
	# By default, uses inc diagonal /, if inverted uses dec \
	var inverted: bool
	var c_left := Content.Nothing
	var c_right := Content.Nothing
	var diag_wall: bool
	# Last seen by a dfs
	var last_seen_left := 0
	var last_seen_right := 0
	static func empty() -> PureCell:
		return PureCell.new()
	func last_seen(corner: E.Corner) -> int:
		if E.corner_is_left(corner):
			return last_seen_left
		else:
			return last_seen_right
	func set_last_seen(corner: E.Corner, val: int) -> void:
		if !diag_wall:
			last_seen_left = val
			last_seen_right = val
		elif E.corner_is_left(corner):
			last_seen_left = val
		else:
			last_seen_right = val
	func _content_at(corner: E.Corner) -> Content:
		if c_left == c_right and !diag_wall:
			return c_left
		match corner:
			E.TopLeft:
				return c_left if !inverted else Content.Nothing
			E.TopRight:
				return c_right if inverted else Content.Nothing
			E.BottomLeft:
				return c_left if inverted else Content.Nothing
			E.BottomRight:
				return c_right if !inverted else Content.Nothing
		assert(false, "Invalid corner")
		return Content.Nothing
	func _content_full(content: Content) -> bool:
		return !diag_wall and c_left == content and c_right == content
	func water_full() -> bool:
		return _content_full(Content.Water)
	func water_at(corner: E.Corner) -> bool:
		return _content_at(corner) == Content.Water
	func air_full() -> bool:
		return _content_full(Content.Air)
	func air_at(corner: E.Corner) -> bool:
		return _content_at(corner) == Content.Air
	func nothing_full() -> bool:
		return _content_full(Content.Nothing)
	func nothing_at(corner: E.Corner) -> bool:
		return _valid_corner(corner) and _content_at(corner) == Content.Nothing
	func block_full() -> bool:
		return _content_full(Content.Block)
	func block_at(corner: E.Corner) -> bool:
		return _content_at(corner) == Content.Block
	func diag_wall_at(diag: E.Diagonal) -> bool:
		match diag:
			E.Diagonal.Dec: # \
				return inverted and diag_wall
			E.Diagonal.Inc: # /
				return !inverted and diag_wall
		assert(false, "Invalid diagonal")
		return false
	# Can't override block
	func put_content(corner: E.Corner, content: Content) -> bool:
		if _content_at(corner) == Content.Block:
			return false
		var prev_left := c_left
		var prev_right := c_right
		if corner == TopLeft or corner == BottomLeft:
			if diag_wall:
				assert(!inverted if corner == TopLeft else inverted, "Invalid corner")
			elif c_right != Content.Block:
				c_right = content
			c_left = content
		else:
			if diag_wall:
				assert(!inverted if corner == BottomRight else inverted, "Invalid corner")
			elif c_left != Content.Block:
				c_left = content
			c_right = content
		return prev_left != c_left or prev_right != c_right
	func put_water(corner: E.Corner) -> bool:
		return put_content(corner, Content.Water)
	func put_air(corner: E.Corner) -> bool:
		return put_content(corner, Content.Air)
	func put_nothing(corner: E.Corner) -> bool:
		return put_content(corner, Content.Nothing)
	func _content_count_from(c: Content, corner: E.Corner) -> float:
		if !diag_wall:
			return _content_count(c)
		if !_valid_corner(corner):
			return 0.
		return 0.5 * (float(c == c_left) if E.corner_is_left(corner) else float(c == c_right))
	func _content_count(c: Content) -> float:
		return 0.5 * (float(c_left == c) + float(c_right == c))
	func water_count() -> float:
		return _content_count(Content.Water)
	func nothing_count() -> float:
		return _content_count(Content.Nothing)
	func eq(other: PureCell) -> bool:
		return c_left == other.c_left and c_right == other.c_right and inverted == other.inverted and diag_wall == other.diag_wall
	func clone() -> PureCell:
		var cell := PureCell.empty()
		cell.c_left = c_left
		cell.c_right = c_right
		cell.inverted = inverted
		cell.diag_wall = diag_wall
		# last_seen doesn't need to be copied
		return cell
	func _block_top() -> bool:
		return _content_at(E.Corner.TopLeft) == Content.Block or _content_at(E.Corner.TopRight) == Content.Block 
	func _block_bottom() -> bool:
			return _content_at(E.Corner.BottomLeft) == Content.Block or _content_at(E.Corner.BottomRight) == Content.Block 
	func _block_left() -> bool:
		return c_left == Content.Block
	func _block_right() -> bool:
		return c_right == Content.Block
	func _valid_corner(corner: E.Corner) -> bool:
		return !diag_wall or (E.corner_to_diag(corner) == E.Diagonal.Dec) == inverted

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
	func water_at(corner: E.Corner) -> bool:
		return pure.water_at(corner)
	func air_full() -> bool:
		return pure.air_full()
	func air_at(corner: E.Corner) -> bool:
		return pure.air_at(corner)
	func nothing_full() -> bool:
		return pure.nothing_full()
	func block_full() -> bool:
		return pure.block_full()
	func block_at(corner: E.Corner) -> bool:
		return pure.block_at(corner)
	func wall_at(side: E.Side) -> bool:
		return grid.wall_at(i, j, side)
	func diag_wall_at(diag: E.Diagonal) -> bool:
		return pure.diag_wall_at(diag)
	func put_water(corner: E.Corner) -> void:
		if !water_at(corner):
			var changes := grid._flood_from(i, j, corner, true)
			grid._push_undo_changes(changes)
	func put_air(corner: E.Corner, flood := false) -> void:
		var changes: Array[Change] = [Change.new(i, j, pure.clone())]
		if water_at(corner):
			# TODO: Everything should go in the same undo
			remove_water_or_air(corner)
		if pure.put_air(corner):
			# No auto-flooding air
			if flood:
				var dfs := AddAirDfs.new(grid)
				dfs.flood(i, j, corner)
				changes.append_array(dfs.changes)
			grid._push_undo_changes(changes)
	func remove_water_or_air(corner: E.Corner) -> void:
		if water_at(corner):
			grid._flood_from(i, j, corner, false)
		var change := Change.new(i, j, pure.clone())
		if pure.put_nothing(corner):
			grid._push_undo_changes([change])

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

func hint_all_rows() -> Array:
	return hint_rows

func set_hint_row(i: int, v: float) -> void:
	hint_rows[i] = v

func hint_col(j: int) -> float:
	return hint_cols[j]

func hint_all_cols() -> Array:
	return hint_cols

func set_hint_col(j: int, v: float) -> void:
	hint_cols[j] = v

func wall_at(i: int, j: int, side: E.Side) -> bool:
	match side:
		E.Side.Left:
			return _has_wall_left(i, j)
		E.Side.Right:
			return _has_wall_right(i, j)
		E.Side.Top:
			return _has_wall_up(i, j)
		E.Side.Bottom:
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
		'#':
			return Content.Block
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
		Content.Block:
			return '#'
	assert(false, "Unknown content")
	return '?'

func _validate_hint(c1: String, c2: String) -> float:
	c1 = _validate(c1, ".123456789")
	c2 = _validate(c2, ".0123456789")
	if c1 != '.':
		return float(c1 + c2.replace(".", "")) / 2.
	else:
		assert(c2 == ".", "Invalid hint")
		return -1.

func load_from_str(s: String) -> void:
	var lines := s.dedent().strip_edges().split('\n', false)
	assert(lines.size() == 2 * n || lines.size() == 2 * n + 1, "Invalid number of rows")
	# 1 if has hints, 0 if not
	var h := int(lines.size() == 2 * n + 1)
	if h == 1:
		for i in n:
			hint_rows[i] = _validate_hint(lines[2 * i + 1][0], lines[2 * i + 2][0])
		for j in m:
			hint_cols[j] = _validate_hint(lines[0][2 * j + 1], lines[0][2 * j + 2])
	for i in n:
		for j in m:
			var c1 := _validate(lines[2 * i + h][2 * j + h], '.wx#')
			var c2 := _validate(lines[2 * i + h][2 * j + 1 + h], '.wx#')
			var c3 := _validate(lines[2 * i + 1 + h][2 * j + h], '.|_L')
			var c4 := _validate(lines[2 * i + 1 + h][2 * j + 1 + h], '.╲/')
			var cell := _pure_cell(i, j)
			cell.c_left = _str_content(c1)
			cell.c_right = _str_content(c2)
			cell.inverted = (c4 == '╲')
			cell.diag_wall = (c4 == '/' or c4 == '╲')
			if i < n - 1:
				wall_down[i][j] = (c3 == '_' or c3 == 'L')
			if j > 0:
				wall_right[i][j - 1] = (c3 == '|' or c3 == 'L')
	validate()

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


func _flood_from(i: int, j: int, corner: E.Corner, water: bool) -> Array[Change]:
	if water:
		var dfs := AddWaterDfs.new(self, i)
		dfs.flood(i, j, corner)
		return dfs.changes
	else:
		var dfs := RemoveWaterDfs.new(self, i)
		dfs.flood(i, j, corner)
		return dfs.changes

class Dfs:
	var grid: GridImpl
	var changes: Array[Change] = []
	func _init(grid_: GridImpl) -> void:
		grid = grid_
		# "Clears" DFS lazily so we make sure we don't visit the same thing twice
		grid.last_seen += 1
	# Returns if it should continue going to nearby cells
	func _cell_logic(_i: int, _j: int, _corner: E.Corner, _cell: PureCell) -> bool:
		return GridModel.must_be_implemented()
	func _can_go_up(_i: int, _j: int) -> bool:
		return GridModel.must_be_implemented()
	func _can_go_down(_i: int, _j: int) -> bool:
		return GridModel.must_be_implemented()
	func flood(i: int, j: int, corner: E.Corner) -> void:
		var cell := grid._pure_cell(i, j)
		if cell.last_seen(corner) == grid.last_seen:
			return
		cell.set_last_seen(corner, grid.last_seen)
		# Try to flood the same cell
		var prev_cell := cell.clone()
		self._cell_logic(i, j, corner, cell)
		if !cell.eq(prev_cell):
			changes.append(Change.new(i, j, prev_cell))
		var is_left := E.corner_is_left(corner)
		var is_top := E.corner_is_top(corner)
		# Try to flood left
		if !grid._has_wall_left(i, j) and !(cell.diag_wall and !is_left):
			flood(i, j - 1, TopRight if grid._pure_cell(i, j - 1).inverted else BottomRight)
		# Try to flood right
		if !grid._has_wall_right(i, j) and !(cell.diag_wall and is_left):
			flood(i, j + 1, BottomLeft if grid._pure_cell(i, j + 1).inverted else TopLeft)
		# Try to flood down
		if !grid._has_wall_down(i, j) and !(cell.diag_wall and is_top) and _can_go_down(i, j):
			flood(i + 1, j, TopRight if grid._pure_cell(i + 1, j).inverted else TopLeft)
		# Try to flood up, if gravity helps
		if !grid._has_wall_up(i, j) and !(cell.diag_wall and !is_top) and _can_go_up(i, j):
			flood(i - 1, j, BottomLeft if grid._pure_cell(i - 1, j).inverted else BottomRight)

class AddWaterDfs extends Dfs:
	# Water can go up to level min_i because of physics
	var min_i: int
	func _init(grid_: GridImpl, min_i_: int) -> void:
		super(grid_)
		min_i = min_i_
	func _cell_logic(_i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		cell.put_water(corner)
		return true
	func _can_go_up(i: int, _j: int) -> bool:
		return i - 1 >= min_i
	func _can_go_down(_i: int, _j: int) -> bool:
		return true


class AddAirDfs extends Dfs:
	func _cell_logic(_i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		cell.put_air(corner)
		return true
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	# TODO: This is incomplete, because we need to move down through water to other "tunnels"
	# But it's hard because we need to be careful about buckets
	func _can_go_down(_i: int, _j: int) -> bool:
		return false

class RemoveWaterDfs extends Dfs:
	# Remove all water at or above min_i
	var min_i: int
	func _init(grid_: GridImpl, min_i_: int) -> void:
		super(grid_)
		min_i = min_i_
	func _cell_logic(i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		# Only keep going if we changed something
		if i <= min_i:
			return cell.put_nothing(corner)
		else:
			return true
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	func _can_go_down(i: int, _j: int) -> bool:
		return i >= min_i

func count_water_row(i: int) -> float:
	var count := 0.
	for j in m:
		count += _pure_cell(i, j).water_count()
	return count

func count_water_col(j: int) -> float:
	var count := 0.
	for i in n:
		count += _pure_cell(i, j).water_count()
	return count

func are_hints_satisfied() -> bool:
	for i in n:
		var hint := hint_rows[i]
		if hint == -1:
			continue
		if count_water_row(i) != hint:
			return false
	for j in m:
		var hint := hint_cols[j]
		if hint == -1:
			continue
		if count_water_col(j) != hint:
			return false
	return true

func is_row_hint_wrong(i : int) -> bool:
	var hint := hint_rows[i]
	if hint == -1:
		return false
	return count_water_row(i) > hint

func is_col_hint_wrong(j : int) -> bool:
	var hint := hint_cols[j]
	if hint == -1:
		return false
	return count_water_col(j) > hint

func is_row_hint_satisfied(i : int) -> bool:
	var hint := hint_rows[i]
	if hint == -1:
		return true
	return count_water_row(i) == hint

func is_col_hint_satisfied(j : int) -> bool:
	var hint := hint_cols[j]
	if hint == -1:
		return true
	return count_water_col(j) == hint

func validate() -> void:
	# For now, just check all blocks are surrounded by walls
	for i in n:
		for j in m:
			var cell := _pure_cell(i, j)
			if cell._block_left() != cell._block_right():
				assert(cell.diag_wall)
			if !_has_wall_left(i, j) and cell._block_left():
				assert(_pure_cell(i, j - 1).block_right())
			if !_has_wall_right(i, j) and cell._block_right():
				assert(_pure_cell(i, j + 1).block_left())
			if !_has_wall_up(i, j) and cell._block_top():
				assert(_pure_cell(i - 1, j)._block_bottom())
			if !_has_wall_down(i, j) and cell._block_bottom():
				assert(_pure_cell(i + 1, j)._block_top())
