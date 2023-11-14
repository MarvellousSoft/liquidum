class_name GridImpl
extends GridModel

static func create(rows_: int, cols_: int) -> GridModel:
	return GridImpl.new(rows_, cols_)

static func from_str(s: String, load_mode := GridModel.LoadMode.Solution) -> GridModel:
	s = s.replace('\r', '').dedent().strip_edges()
	var my_s := s
	while my_s[0] == '+':
		my_s = my_s.split("\n", false, 1)[1]
	# Integer division round down makes this work even with hints
	var rows_ := (my_s.count('\n') + 1) / 2
	var cols_ := my_s.find('\n') / 2
	assert(rows_ > 0 and cols_ > 0)
	if my_s[0] == 'b' and my_s.find('h') != -1:
		rows_ -= 1
		cols_ -= 1
	var g := GridImpl.new(rows_, cols_)
	g.load_from_str(s, load_mode)
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
# TODO: Rename to _row_hints
var hint_rows: Array[LineHint]
var hint_cols: Array[LineHint]
var expected_waters: float = 0.0
var expected_boats: int = 0
# (N-1)xM Array[Array[bool]]
var wall_bottom: Array[Array]
# Nx(M-1) Array[Array[bool]]
var wall_right: Array[Array]
# Optimization for DFSs
var last_seen := 0
# List of changes to undo and redo
var undo_stack: Array[Changes] = []
var redo_stack: Array[Changes] = []
var expected_aquariums: Array[float] = []

var solution_c_left: Array[Array]
var solution_c_right: Array[Array]

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
			wall_bottom.append(row_down)
	for i in n:
		var hint_row := LineHint.new()
		hint_row.water_count = -1.
		hint_row.water_count_type = E.HintType.Any
		hint_row.boat_count = -1
		hint_row.boat_count_type = E.HintType.Any
		hint_rows.append(hint_row)
	for j in m:
		var hint_col := LineHint.new()
		hint_col.water_count = -1.
		hint_col.water_count_type = E.HintType.Any
		hint_col.boat_count = -1
		hint_col.boat_count_type = E.HintType.Any
		hint_cols.append(hint_col)

enum Content { Nothing, Water, Air, Block, Boat }

func _is_content_partial_solution(c: Content, sol: Content) -> bool:
	match c:
		Content.Block, Content.Water, Content.Boat:
			return sol == c
		Content.Nothing, Content.Air:
			return true
	return true

func _content_sol(i: int, j: int, corner: E.Corner) -> Content:
	if E.corner_is_left(corner):
		return solution_c_left[i][j]
	else:
		return solution_c_right[i][j]

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
	func _diag_wall_at(diag: E.Diagonal) -> bool:
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
	func _put_boat() -> bool:
		if diag_wall:
			return false
		# Only things that can be replaced with boat
		if c_left != Content.Nothing and c_left != Content.Air:
			return false
		c_left = Content.Boat
		c_right = Content.Boat
		return true
	func _has_boat() -> bool:
		return c_left == Content.Boat
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
	func _content_top() -> Content:
		return c_right if inverted else c_left
	func _content_right() -> Content:
		return c_right
	func _content_bottom() -> Content:
		return c_left if inverted else c_right
	func _content_left() -> Content:
		return c_left
	func _valid_corner(corner: E.Corner) -> bool:
		return !diag_wall or (E.corner_to_diag(corner) == E.Diagonal.Dec) == inverted
	func _change_diag_wall(diag: E.Diagonal, new: bool) -> void:
		if new:
			c_left = Content.Nothing
			c_right = Content.Nothing
		diag_wall = new
		inverted = (diag == E.Diagonal.Dec)
	func cell_type() -> E.CellType:
		if diag_wall:
			if inverted:
				return E.CellType.DecDiag
			else:
				return E.CellType.IncDiag
		else:
			return E.CellType.Single

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
	var i: int
	var j: int
	var grid: GridImpl
	func _init(i_: int, j_: int, grid_: GridImpl) -> void:
		self.i = i_
		self.j = j_
		self.grid = grid_
	func pure() -> PureCell:
		return grid._pure_cell(i, j)
	func water_full() -> bool:
		return pure().water_full()
	func water_at(corner: E.Corner) -> bool:
		return pure().water_at(corner)
	func air_full() -> bool:
		return pure().air_full()
	func air_at(corner: E.Corner) -> bool:
		return pure().air_at(corner)
	func nothing_full() -> bool:
		return pure().nothing_full()
	func nothing_at(corner: E.Corner) -> bool:
		return pure().nothing_at(corner)
	func block_full() -> bool:
		return pure().block_full()
	func block_at(corner: E.Corner) -> bool:
		return pure().block_at(corner)
	func wall_at(wall: E.Walls) -> bool:
		match wall:
			E.Top, E.Right, E.Bottom, E.Left:
				return grid.wall_at(i, j, wall as E.Side)
			E.Inc, E.Dec:
				return pure()._diag_wall_at(wall as E.Diagonal)
		push_error("Bad wall %d" % wall)
		return false
	func put_water(corner: E.Corner, flush_undo := true) -> bool:
		if !grid.is_corner_partially_valid(Content.Water, i, j, corner):
			return false
		if !water_at(corner):
			var changes := grid._flood_water(i, j, corner, true)
			grid._push_undo_changes(changes, flush_undo)
		return true
	func put_air(corner: E.Corner, flush_undo := true, flood := false) -> bool:
		if flush_undo:
			grid.push_empty_undo()
		if !grid.is_corner_partially_valid(Content.Air, i, j, corner):
			return false
		if water_at(corner):
			remove_content(corner, false)
		var changes: Array[Change] = [Change.new(i, j, pure().clone())]
		if pure().put_air(corner):
			# No auto-flooding air
			if flood:
				var dfs := AddAirDfs.new(grid)
				dfs.flood(i, j, corner)
				changes.append_array(dfs.changes)
			grid._push_undo_changes(changes, false)
		return true
	func remove_content(corner: E.Corner, flush_undo := true) -> void:
		var changes: Array[Change] = []
		if water_at(corner):
			changes.append_array(grid._flood_water(i, j, corner, false))
		var change := Change.new(i, j, pure().clone())
		if pure().put_nothing(corner):
			changes.append(change)
		grid._push_undo_changes(changes, flush_undo)
	func _change_wall(wall: E.Walls, new: bool, _flush_undo: bool) -> void:
		# TODO: Add walls to undo
		match wall:
			E.Top, E.Left, E.Right, E.Bottom:
				return grid._change_wall(i, j, wall as E.Side, new)
			E.Dec, E.Inc:
				return pure()._change_diag_wall(wall as E.Diagonal, new)
	func put_wall(wall: E.Walls, flush_undo := true) -> void:
		_change_wall(wall, true, flush_undo)
	func remove_wall(wall: E.Walls, flush_undo := true) -> void:
		_change_wall(wall, false, flush_undo)
	func put_boat(flush_undo := true) -> bool:
		if i == grid.rows() - 1:
			return false
		var c := grid.get_cell(i + 1, j)
		if not (c.water_at(E.Corner.TopLeft) or c.water_at(E.Corner.TopRight)):
			return false
		if !grid.is_corner_partially_valid(Content.Boat, i, j, E.Corner.TopRight):
			return false
		var changes: Array[Change] = [Change.new(i, j, pure().clone())]
		if pure()._put_boat():
			grid._push_undo_changes(changes, flush_undo)
			return true
		return false
	func has_boat() -> bool:
		return pure()._has_boat()
	func cell_type() -> E.CellType:
		return pure().cell_type()

func rows() -> int:
	return n

func cols() -> int:
	return m

func _pure_cell(i: int, j: int) -> PureCell:
	return pure_cells[i][j]

func get_cell(i: int, j: int) -> CellModel:
	return CellWithLoc.new(i, j, self)

# TODO: Rename
func set_hint_row(i: int, v: float) -> void:
	hint_rows[i].water_count = v

# TODO: Rename
func set_hint_col(j: int, v: float) -> void:
	hint_cols[j].water_count = v

func row_hints() -> Array[LineHint]:
	return hint_rows

func col_hints() -> Array[LineHint]:
	return hint_cols

func get_expected_boats() -> int:
	return expected_boats

func get_expected_waters() -> float:
	return expected_waters

func wall_at(i: int, j: int, side: E.Side) -> bool:
	match side:
		E.Side.Left:
			return _has_wall_left(i, j)
		E.Side.Right:
			return _has_wall_right(i, j)
		E.Side.Top:
			return _has_wall_top(i, j)
		E.Side.Bottom:
			return _has_wall_bottom(i, j)
	assert(false, "Invalid side")
	return false

func _has_wall_bottom(i: int, j: int) -> bool:
	return i == n - 1 or wall_bottom[i][j]

func _has_wall_top(i: int, j: int) -> bool:
	return i == 0 or _has_wall_bottom(i - 1, j)

func _has_wall_right(i: int, j: int) -> bool:
	return j == m - 1 or wall_right[i][j]

func _has_wall_left(i: int, j: int) -> bool:
	return j == 0 or _has_wall_right(i, j - 1)

func _change_wall(i: int, j: int, side: E.Side, new: bool) -> void:
	if side == E.Left:
		return _change_wall(i, j - 1, E.Side.Right, new)
	if side == E.Top:
		return _change_wall(i - 1, j, E.Side.Bottom, new)
	if side == E.Right and j >= 0 and j < m - 1:
		wall_right[i][j] = new
	if side == E.Bottom and i >= 0 and i < n - 1:
		wall_bottom[i][j] = new

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
		'b':
			return Content.Boat
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
		Content.Boat:
			return 'b'
	assert(false, "Unknown content")
	return '?'

func _validate_hint(c1: String, c2: String) -> int:
	c1 = _validate(c1, ".0123456789")
	c2 = _validate(c2, ".0123456789")
	if c1 != '.':
		return int(c1 + c2.replace(".", ""))
	else:
		assert(c2 == ".", "Invalid hint")
		return -1

func _validate_hint_float(c1: String, c2: String) -> float:
	var h := _validate_hint(c1, c2)
	if h == -1:
		return -1.
	else:
		return float(h) / 2.

func _parse_extra_data(line: String) -> void:
	var kv := line.split("=", false, 2)
	match kv[0]:
		"+waters":
			expected_waters = int(kv[1])
		"+boats":
			expected_boats = int(kv[1])
		"+aqua":
			expected_aquariums.append(float(kv[1]))
		_:
			push_error("Invalid data %s" % line)

func load_from_str(s: String, load_mode := GridModel.LoadMode.Solution) -> void:
	var content_only := (load_mode == GridModel.LoadMode.ContentOnly)
	var lines := s.dedent().strip_edges().split('\n', false)
	while lines[0][0] == '+':
		if not content_only:
			_parse_extra_data(lines[0])
		lines.remove_at(0)
	# Offset because of hints
	var hb := int(lines[0][0] == 'b')
	var hh := int(lines[hb][hb] == 'h')
	if hb == 1 and not content_only:
		for i in n:
			hint_rows[i].boat_count = _validate_hint(lines[2 * i + 1 + hh][0], lines[2 * i + 2 + hh][0])
		for j in m:
			hint_cols[j].boat_count = _validate_hint(lines[0][2 * j + 1 + hh], lines[0][2 * j + 2 + hh])
	if hh == 1 and not content_only:
		for i in n:
			hint_rows[i].water_count = _validate_hint_float(lines[2 * i + 1 + hb][hb], lines[2 * i + 2 + hb][hb])
		for j in m:
			hint_cols[j].water_count = _validate_hint_float(lines[hb][2 * j + 1 + hb], lines[hb][2 * j + 2 + hb])
	var h := hb + hh
	for i in n:
		for j in m:
			var c1 := _validate(lines[2 * i + h][2 * j + h], '.wxb#')
			var c2 := _validate(lines[2 * i + h][2 * j + 1 + h], '.wxb#')
			var c3 := _validate(lines[2 * i + 1 + h][2 * j + h], '.|_L')
			var c4 := _validate(lines[2 * i + 1 + h][2 * j + 1 + h], '.╲/')
			var cell := _pure_cell(i, j)
			if not content_only or cell.c_left != Content.Block:
				cell.c_left = _str_content(c1)
			if not content_only or cell.c_right != Content.Block:
				cell.c_right = _str_content(c2)
			if not content_only:
				cell.inverted = (c4 == '╲')
				cell.diag_wall = (c4 == '/' or c4 == '╲')
				if i < n - 1:
					wall_bottom[i][j] = (c3 == '_' or c3 == 'L')
				if j > 0:
					wall_right[i][j - 1] = (c3 == '|' or c3 == 'L')
	flood_all()
	validate()

	if load_mode == GridModel.LoadMode.Solution or load_mode == GridModel.LoadMode.SolutionNoClear:
		assert(are_hints_satisfied(), "Invalid solution")
		solution_c_left.clear()
		solution_c_right.clear()
		for i in n:
			solution_c_left.append(pure_cells[i].map(func(c): return c.c_left))
			solution_c_right.append(pure_cells[i].map(func(c): return c.c_right))
		if load_mode != GridModel.LoadMode.SolutionNoClear:
			clear_content()

func _col_hint(h: int) -> String:
	if h < 0:
		return ".."
	if h < 10:
		return "%d." % h
	else:
		# Will crash if h >= 100
		return "%d" % h

func _row_hint1(h: int) -> String:
	if h < 0:
		return "."
	elif h >= 10:
		return "%d" % (h / 10)
	else:
		return "%d" % h

func _row_hint2(h: int) -> String:
	if h >= 10:
		return "%d" % (h % 10)
	else:
		return "."

func to_str() -> String:
	var builder := PackedStringArray()
	if expected_waters != 0:
		builder.append("+waters=%d\n" % expected_waters)
	if expected_boats != 0:
		builder.append("+boats=%d\n" % expected_boats)
	var boat_hints := hint_rows.any(func(h): return h.boat_count != -1) or hint_cols.any(func(h): return h.boat_count != -1)
	var hints := hint_rows.any(func(h): return h.water_count != -1.) or hint_cols.any(func(h): return h.water_count != -1.)
	if boat_hints:
		builder.append('b')
		if hints:
			builder.append('.')
		for j in m:
			builder.append(_col_hint(hint_cols[j].boat_count))
		builder.append('\n')
	if hints:
		if boat_hints:
			builder.append('.')
		builder.append('h')
		for j in m:
			builder.append(_col_hint(int(hint_cols[j].water_count * 2)))
		builder.append('\n')
	for i in n:
		if boat_hints:
			builder.append(_row_hint1(hint_rows[i].boat_count))
		if hints:
			builder.append(_row_hint1(int(hint_rows[i].water_count * 2)))
		for j in m:
			var cell := _pure_cell(i, j)
			builder.append(_content_str(cell.c_left))
			builder.append(_content_str(cell.c_right))
		builder.append("\n")
		if boat_hints:
			builder.append(_row_hint2(hint_rows[i].boat_count))
		if hints:
			builder.append(_row_hint2(int(hint_rows[i].water_count * 2)))
		for j in m:
			var left := _has_wall_left(i, j)
			var down := _has_wall_bottom(i, j)
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

func _undo_impl(undos: Array[Changes], redos: Array[Changes]) -> bool:
	while not undos.is_empty() and (undos.back() as Changes).changes.is_empty():
		undos.pop_back()
	if undos.is_empty():
		return false
	var changes: Array[Change] = undos.pop_back().changes
	var already_done = {}
	for c in changes:
		if already_done.has(Vector2i(c.i, c.j)):
			continue
		already_done[Vector2i(c.i, c.j)] = true
		var now_cell: PureCell = pure_cells[c.i][c.j]
		pure_cells[c.i][c.j] = c.prev_cell
		# Maybe clone isn't necessary, but let's be safe
		c.prev_cell = now_cell.clone()
	# changes is now the changes to redo the undo
	redos.push_back(Changes.new(changes))
	assert(!flood_all())
	return true

func push_empty_undo() -> void:
	_push_undo_changes([], true)

func undo() -> bool:
	return _undo_impl(undo_stack, redo_stack)

func redo() -> bool:
	# Beautifully, redo works exactly the same as undo
	return _undo_impl(redo_stack, undo_stack)

func _push_undo_changes(changes: Array[Change], flush_first: bool) -> void:
	redo_stack.clear()
	if flush_first or undo_stack.is_empty():
		undo_stack.push_back(Changes.new(changes))
	else:
		undo_stack.back().changes.append_array(changes)


func _flood_water(i: int, j: int, corner: E.Corner, add: bool) -> Array[Change]:
	if add:
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
	# Called when visiting this cell for the first time. It might be only half a cell
	# or the whole cell. If this cell doesn't have a diagonal, this function is called
	# only ONCE for it, be careful.
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
		if !grid._has_wall_bottom(i, j) and !(cell.diag_wall and is_top) and _can_go_down(i, j):
			flood(i + 1, j, TopRight if grid._pure_cell(i + 1, j).inverted else TopLeft)
		# Try to flood up, if gravity helps
		if !grid._has_wall_top(i, j) and !(cell.diag_wall and !is_top) and _can_go_up(i, j):
			flood(i - 1, j, BottomLeft if grid._pure_cell(i - 1, j).inverted else BottomRight)

class AddWaterDfs extends Dfs:
	# Water can go up to level min_i because of physics
	var min_i: int
	func _init(grid_: GridImpl, min_i_: int) -> void:
		super(grid_)
		min_i = min_i_
	func _cell_logic(_i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		match cell._content_at(corner):
			Content.Nothing, Content.Air, Content.Boat, Content.Water:
				cell.put_water(corner)
		return true
	func _can_go_up(i: int, _j: int) -> bool:
		return i - 1 >= min_i
	func _can_go_down(_i: int, _j: int) -> bool:
		return true


class AddAirDfs extends Dfs:
	func _cell_logic(_i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		match cell._content_at(corner):
			Content.Water, Content.Nothing, Content.Air:
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
			match cell._content_at(corner):
				Content.Water:
					return cell.put_nothing(corner)
				# Remove boat but don't continue
				Content.Boat:
					cell.put_nothing(corner)
			return false
		else:
			return true
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	func _can_go_down(i: int, _j: int) -> bool:
		return i >= min_i

class CountWaterDfs extends Dfs:
	var water_count: float
	func _cell_logic(i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		water_count += cell._content_count_from(Content.Water, corner)
		return true
	# Walk whole aquarium
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	func _can_go_down(i: int, _j: int) -> bool:
		return true

func aquarium_hints() -> Array[float]:
	return expected_aquariums

func _all_aquariums_count() -> Array[float]:
	var dfs := CountWaterDfs.new(self)
	var counts: Array[float] = []
	for i in n:
		for j in m:
			for corner in E.Corner.values():
				if _pure_cell(i, j)._valid_corner(corner) and _pure_cell(i, j).last_seen(corner) < last_seen:
					dfs.water_count = 0
					dfs.flood(i, j, corner)
					counts.append(dfs.water_count)
	return counts

func satisfied_aquarium_hints() -> Array[bool]:
	var aqs := _all_aquariums_count()
	var count: Dictionary = {}
	for aq in aqs:
		count[aq] = count.get(aq, 0) + 1
	var satisfied: Array[bool] = []
	for hint in expected_aquariums:
		if count.get(hint, 0) > 0:
			count[hint] -= 1
			satisfied.append(true)
		else:
			satisfied.append(false)
	return satisfied

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

func count_boat_row(i: int) -> int:
	var count := 0
	for j in m:
		count += int(_pure_cell(i, j)._has_boat())
	return count

func count_boat_col(j: int) -> int:
	var count := 0
	for i in n:
		count += int(_pure_cell(i, j)._has_boat())
	return count

func count_boats() -> int:
	var count := 0
	for i in n:
		count += count_boat_row(i)
	return count


func count_waters() -> float:
	var count := 0.0
	for i in n:
		count += count_water_row(i)
	return count


func are_hints_satisfied() -> bool:
	if count_boats() != get_expected_boats():
		return false
	for i in n:
		var hint := hint_rows[i].water_count
		if hint != -1 and count_water_row(i) != hint:
			return false
		var hint_boat := hint_rows[i].boat_count
		if hint_boat != -1 and count_boat_row(i) != hint_boat:
			return false
		# Maybe I also need to check no boats are placed randomly without hints
	for j in m:
		var hint := hint_cols[j].water_count
		if hint != -1 and count_water_col(j) != hint:
			return false
		var hint_boat := hint_cols[j].boat_count
		if hint_boat != -1 and count_boat_col(j) != hint_boat:
			return false
	if not satisfied_aquarium_hints().all(func(x): return x):
		return false
	return true

func is_any_hint_broken() -> bool:
	if count_boats() > get_expected_boats():
		return true
	for i in n:
		if get_row_hint_status(i, E.HintContent.Water) == E.HintStatus.Wrong:
			return true
		var h := hint_rows[i].boat_count
		if h != -1 and count_boat_row(i) > h:
			return false
	for j in m:
		if get_col_hint_status(j, E.HintContent.Water) == E.HintStatus.Wrong:
			return true
		var h := hint_cols[j].boat_count
		if h != -1 and count_boat_col(j) > h:
			return false
	return false

func get_row_hint_status(i : int, hint_type : E.HintContent) -> E.HintStatus:
	var hint = float(hint_rows[i].boat_count) if hint_type == E.HintContent.Boat else hint_rows[i].water_count
	if hint == -1:
		return E.HintStatus.Unknown
	var count = float(count_boat_row(i)) if hint_type == E.HintContent.Boat else count_water_row(i)
	if count < hint:
		return E.HintStatus.Normal
	elif count > hint:
		return E.HintStatus.Wrong
	else:
		return E.HintStatus.Satisfied

func get_col_hint_status(j : int, hint_type : E.HintContent) -> E.HintStatus:
	var hint = float(hint_cols[j].boat_count) if hint_type == E.HintContent.Boat else hint_cols[j].water_count
	if hint == -1:
		return E.HintStatus.Unknown
	var count = float(count_boat_col(j)) if hint_type == E.HintContent.Boat else count_water_col(j)
	if count < hint:
		return E.HintStatus.Normal
	elif count > hint:
		return E.HintStatus.Wrong
	else:
		return E.HintStatus.Satisfied

# Use when level is created with with_solution
func is_solution_partially_valid() -> bool:
	assert(!solution_c_left.is_empty() or n == 0)
	for i in n:
		for j in m:
			if not _is_content_partial_solution(_pure_cell(i, j).c_left, solution_c_left[i][j]):
				return false
			if not _is_content_partial_solution(_pure_cell(i, j).c_right, solution_c_right[i][j]):
				return false
	return true

func is_corner_partially_valid(c: Content, i: int, j: int, corner: E.Corner) -> bool:
	return solution_c_left.is_empty() or _is_content_partial_solution(c, _content_sol(i, j, corner))

func validate() -> void:
	if !expected_aquariums.is_empty():
		for i in expected_aquariums.size() - 1:
			assert(expected_aquariums[i] <= expected_aquariums[i + 1])
	# Blocks are surrounded by walls
	for i in n:
		for j in m:
			var cell := _pure_cell(i, j)
			if (cell._content_left() == Content.Block) != (cell._content_right() == Content.Block):
				assert(cell.diag_wall)
			if !_has_wall_left(i, j) and cell._content_left() == Content.Block:
				assert(_pure_cell(i, j - 1)._content_right() == Content.Block)
			if !_has_wall_right(i, j) and cell._content_right() == Content.Block:
				assert(_pure_cell(i, j + 1)._content_left() == Content.Block)
			if !_has_wall_top(i, j) and cell._content_top() == Content.Block:
				assert(_pure_cell(i - 1, j)._content_bottom() == Content.Block)
			if !_has_wall_bottom(i, j) and cell._content_bottom() == Content.Block:
				assert(_pure_cell(i + 1, j)._content_top() == Content.Block)
	# Boats make sense
	for i in n:
		for j in m:
			var c := _pure_cell(i, j)
			assert((c._content_left() == Content.Boat) == (c._content_right() == Content.Boat))
			if get_cell(i, j).has_boat():
				assert(not _pure_cell(i, j).diag_wall)
				assert(i < n - 1 and _pure_cell(i + 1, j)._content_top() == Content.Water)

func flood_all() -> bool:
	var dfs := AddWaterDfs.new(self, 0)
	# Top down is important for correctness
	for i in n:
		for j in m:
			var c := _pure_cell(i, j)
			for corner in E.Corner.values():
				if c.last_seen(corner) < last_seen and c.water_at(corner):
					dfs.min_i = i
					dfs.flood(i, j, corner)
	if !dfs.changes.is_empty():
		_push_undo_changes(dfs.changes, true)
		return true
	return false

func flood_air(flush_undo := true) -> bool:
	if flush_undo:
		push_empty_undo()
	var dfs := AddAirDfs.new(self)
	for i in range(n - 1, -1, -1):
		for j in m:
			var c := _pure_cell(i, j)
			for corner in E.Corner.values():
				if c.last_seen(corner) < last_seen and c.air_at(corner):
					dfs.flood(i, j, corner)
	if !dfs.changes.is_empty():
		_push_undo_changes(dfs.changes, false)
		return true
	return false

func clear_content() -> void:
	for i in n:
		for j in m:
			var c := _pure_cell(i, j)
			if c.c_left != Content.Block:
				c.c_left = Content.Nothing
			if c.c_right != Content.Block:
				c.c_right = Content.Nothing
