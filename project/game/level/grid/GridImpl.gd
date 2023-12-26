class_name GridImpl
extends GridModel

static func empty_editor(rows_: int, cols_: int) -> GridModel:
	var g := GridImpl.new(rows_, cols_)
	g.set_auto_update_hints(true)
	return g

static func import_data(data: Dictionary, load_mode: LoadMode) -> GridModel:
	assert(load_mode != LoadMode.ContentOnly)
	return GridExporter.new().load_data(GridImpl.new(0, 0), data, load_mode)

static func from_str(s: String, load_mode := GridModel.LoadMode.Solution) -> GridModel:
	s = s.replace('\r', '').dedent().strip_edges()
	var my_s := s
	while my_s[0] == '+':
		my_s = my_s.split("\n", false, 1)[1]
	# Integer division round down makes this work even with hints
	var rows_ := (my_s.count('\n') + 1) / 2
	var cols_ := my_s.find('\n') / 2
	assert(rows_ > 0 and cols_ > 0)
	if my_s[0] == 'B' and my_s.find('h') != -1:
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
var _row_hints: Array[LineHint]
var _col_hints: Array[LineHint]
var _grid_hints: GridHints
# (N-1)xM Array[Array[bool]]
var wall_bottom: Array[Array]
# Nx(M-1) Array[Array[bool]]
var wall_right: Array[Array]
# Optimization for DFSs
var last_seen := 0
# List of changes to undo and redo
var undo_stack: Array[Changes] = []
var redo_stack: Array[Changes] = []

var solution_c_left: Array[Array]
var solution_c_right: Array[Array]
var auto_update_hints_: bool = false
var _force_editor_mode := false

func _init(n_: int, m_: int) -> void:
	setup(n_, m_)

func _empty_line_hint() -> LineHint:
	var hint := LineHint.new()
	hint.water_count = -1.
	hint.water_count_type = E.HintType.Hidden
	hint.boat_count = -1
	hint.boat_count_type = E.HintType.Hidden
	return hint

func setup(n_: int, m_: int) -> void:
	self.n = n_
	self.m = m_
	pure_cells = []
	wall_right = []
	wall_bottom = []
	_row_hints = []
	_col_hints = []
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
		_row_hints.append(_empty_line_hint())
	for j in m:
		_col_hints.append(_empty_line_hint())
	_grid_hints = GridHints.new()
	_grid_hints.total_water = -1.
	_grid_hints.total_boats = 0
	_grid_hints.expected_aquariums = {}

static func empty_ish(c: Content) -> bool:
	match c:
		Content.NoWater, Content.NoBoat, Content.NoBoatWater, Content.Nothing:
			return true
		Content.Block, Content.Water, Content.Boat:
			return false
	push_error("Unknown content %d" % c)
	return false

enum Content { Nothing, Water, NoWater, Block, Boat, NoBoat, NoBoatWater }

func _is_content_partial_solution(c: Content, sol: Content) -> bool:
	match c:
		Content.Block, Content.Water, Content.Boat:
			return sol == c
		Content.Nothing, Content.NoWater, Content.NoBoat, Content.NoBoatWater:
			return true
	push_error("Unknown content %d" % c)
	return true

func _content_sol(i: int, j: int, corner: E.Corner) -> Content:
	if E.corner_is_left(corner):
		return solution_c_left[i][j]
	else:
		return solution_c_right[i][j]

class PureCell:
	var c_left := Content.Nothing
	var c_right := Content.Nothing
	var type: E.CellType = E.CellType.Single
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
		if type == E.Single:
			last_seen_left = val
			last_seen_right = val
		elif E.corner_is_left(corner):
			last_seen_left = val
		else:
			last_seen_right = val
	func _content_at(corner: E.Corner) -> Content:
		# Maybe c_left != c_right if it's not properly flooded
		if type == E.Single:
			return c_left if E.corner_is_left(corner) else c_right
		match corner:
			E.TopLeft:
				return c_left if type == E.Inc else Content.Nothing
			E.TopRight:
				return c_right if type == E.Dec else Content.Nothing
			E.BottomLeft:
				return c_left if type == E.Dec else Content.Nothing
			E.BottomRight:
				return c_right if type == E.Inc else Content.Nothing
		assert(false, "Invalid corner")
		return Content.Nothing
	func _content_full(content: Content) -> bool:
		return type == E.Single and c_left == content and c_right == content
	func water_full() -> bool:
		return _content_full(Content.Water)
	func water_at(corner: E.Corner) -> bool:
		return _content_at(corner) == Content.Water
	func nowater_full() -> bool:
		return _content_full(Content.NoWater)
	func nowater_at(corner: E.Corner) -> bool:
		return _content_at(corner) == Content.NoWater
	func nothing_full() -> bool:
		return _content_full(Content.Nothing)
	func nothing_at(corner: E.Corner) -> bool:
		return _valid_corner(corner) and _content_at(corner) == Content.Nothing
	func block_full() -> bool:
		return _content_full(Content.Block)
	func block_at(corner: E.Corner) -> bool:
		return _content_at(corner) == Content.Block
	func _diag_wall_at(diag: E.Diagonal) -> bool:
		return diag == type
	# Can't override block
	func put_content(corner: E.Corner, content: Content, force_no_mix := false) -> bool:
		if not _valid_corner(corner):
			return false

		var prev_left := c_left
		var prev_right := c_right
		if not force_no_mix:
			# Maybe mix NoBoat and NoWater
			match [content, _content_at(corner)]:
				[Content.NoBoat, Content.NoWater], [Content.NoWater, Content.NoBoat], [Content.NoBoat, Content.NoBoatWater], [Content.NoWater, Content.NoBoatWater]:
					content = Content.NoBoatWater
		if E.corner_is_left(corner):
			if type == E.Single:
				c_right = content
			c_left = content
		else:
			if type == E.Single:
				c_left = content
			c_right = content
		return prev_left != c_left or prev_right != c_right
	func put_water(corner: E.Corner) -> bool:
		return put_content(corner, Content.Water)
	func put_nowater(corner: E.Corner, force_no_mix: bool) -> bool:
		return put_content(corner, Content.NoWater, force_no_mix)
	func put_noboat(corner: E.Corner, force_no_mix: bool) -> bool:
		return put_content(corner, Content.NoBoat, force_no_mix)
	func put_block(corner: E.Corner) -> bool:
		return put_content(corner, Content.Block)
	func put_nothing(corner: E.Corner) -> bool:
		return put_content(corner, Content.Nothing)
	func _put_boat() -> bool:
		if type != E.Single:
			return false
		# Only things that can be replaced with boat
		if c_left != Content.Nothing and c_left != Content.NoWater:
			return false
		c_left = Content.Boat
		c_right = Content.Boat
		return true
	func _has_boat() -> bool:
		return c_left == Content.Boat
	func _content_count_from(c: Content, corner: E.Corner) -> float:
		if type == E.Single:
			return _content_count(c)
		if !_valid_corner(corner):
			return 0.
		return 0.5 * (float(c == c_left) if E.corner_is_left(corner) else float(c == c_right))
	func _content_count(c: Content) -> float:
		return 0.5 * (float(c_left == c) + float(c_right == c))
	func water_count() -> float:
		return _content_count(Content.Water)
	func nowater_count() -> float:
		return _content_count(Content.NoWater)
	func nothing_count() -> float:
		return _content_count(Content.Nothing)
	func eq(other: PureCell) -> bool:
		return c_left == other.c_left and c_right == other.c_right and type == other.type
	func clone() -> PureCell:
		var cell := PureCell.empty()
		cell.c_left = c_left
		cell.c_right = c_right
		cell.type = type
		# last_seen doesn't need to be copied
		return cell
	func _content_top() -> Content:
		return _content_side(E.Side.Top)
	func _content_right() -> Content:
		return c_right
	func _content_bottom() -> Content:
		return _content_side(E.Side.Bottom)
	func _content_left() -> Content:
		return c_left
	func _content_side(side: E.Side) -> Content:
		match side:
			E.Top:
				return c_right if type == E.Dec else c_left
			E.Right:
				return c_right
			E.Bottom:
				return c_left if type == E.Dec else c_right
			E.Left:
				return c_left
		assert(false, "Invalid size")
		return Content.Nothing
	func _valid_corner(corner: E.Corner) -> bool:
		return type == E.Single or E.corner_to_diag(corner) == type
	func _change_diag_wall(diag: E.Diagonal, new: bool) -> void:
		if new:
			# Water and nowater are fine to keep. If changing diagonal let's purge everything.
			if _has_boat() or (c_left != c_right and type != E.Single and type != diag):
				c_left = Content.Nothing
				c_right = Content.Nothing
			type = diag as E.CellType
		else:
			type = E.CellType.Single
	func cell_type() -> E.CellType:
		return type
	func corners() -> Array[E.Corner]:
		match type:
			E.CellType.Single:
				return [E.Corner.TopLeft]
			E.CellType.DecDiag:
				return [E.Corner.BottomLeft, E.Corner.TopRight]
			E.CellType.IncDiag:
				return [E.Corner.TopLeft, E.Corner.BottomRight]
		push_error("Unknown type %d" % type)
		return []
	func equal(other: PureCell) -> bool:
		return eq(other)
	func to_str() -> String:
		return "PureCell(%s, %s, %s)" % [E.CellType.find_key(type), Content.find_key(c_left), Content.find_key(c_right)]

class Change:
	# Undo the changes and return a change that redoes the changes. Might be self.
	func undo(_grid: GridImpl) -> Change:
		return GridModel.must_be_implemented()

class CellChange extends Change:
	var i: int
	var j: int
	var prev_cell: PureCell
	func _init(i_: int, j_: int, prev_cell_: PureCell) -> void:
		i = i_
		j = j_
		prev_cell = prev_cell_
	func undo(grid: GridImpl) -> Change:
		# Maybe clone isn't necessary, but let's be safe
		var new_cell: PureCell = grid.pure_cells[i][j].clone()
		grid.pure_cells[i][j] = prev_cell
		prev_cell = new_cell
		return self

class WallChange extends Change:
	var i: int
	var j: int
	var side: E.Side
	var present: bool
	func _init(i_: int, j_: int, side_: E.Side, present_: bool) -> void:
		i = i_
		j = j_
		side = side_
		present = present_
	func undo(grid: GridImpl) -> Change:
		var now_present := grid.wall_at(i, j, side)
		grid._change_wall(i, j, side, present)
		present = now_present
		return self

class AddRowChange extends Change:
	func undo(grid: GridImpl) -> Change:
		return grid._do_rem_row()

class RemRowChange extends Change:
	var prev_row: Array[PureCell]
	var prev_wall_bottom: Array[bool]
	var prev_wall_right: Array[bool]
	var prev_hint: LineHint
	func _init(prev_row_: Array[PureCell], prev_wall_bottom_: Array[bool], prev_wall_right_: Array[bool], prev_hint_: LineHint) -> void:
		prev_row = prev_row_
		prev_wall_bottom = prev_wall_bottom_
		prev_wall_right = prev_wall_right_
		prev_hint = prev_hint_
	func undo(grid: GridImpl) -> Change:
		return grid._do_add_row(prev_row, prev_wall_bottom, prev_wall_right, prev_hint)

class AddColChange extends Change:
	func undo(grid: GridImpl) -> Change:
		return grid._do_rem_col()

class RemColChange extends Change:
	var prev_col: Array[PureCell]
	var prev_wall_bottom: Array[bool]
	var prev_wall_right: Array[bool]
	var prev_hint: LineHint
	func _init(prev_col_: Array[PureCell], prev_wall_bottom_: Array[bool], prev_wall_right_: Array[bool], prev_hint_: LineHint) -> void:
		prev_col = prev_col_
		prev_wall_bottom = prev_wall_bottom_
		prev_wall_right = prev_wall_right_
		prev_hint = prev_hint_
	func undo(grid: GridImpl) -> Change:
		return grid._do_add_col(prev_col, prev_wall_bottom, prev_wall_right, prev_hint)

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
	func nowater_full() -> bool:
		return pure().nowater_full()
	func nowater_at(corner: E.Corner) -> bool:
		return pure().nowater_at(corner)
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
	func put_water(corner: E.Corner, flush_undo := true) -> float:
		if !grid.is_corner_partially_valid(Content.Water, i, j, corner):
			return false
		var added_waters := 0.0
		if !water_at(corner):
			var dfs := grid._flood_water(i, j, corner, true)
			added_waters = (dfs as AddWaterDfs).added_waters
			grid._push_undo_changes(dfs.changes, flush_undo)
		grid.maybe_update_hints()
		return added_waters
	func put_block(corner: E.Corner, flush_undo := true) -> bool:
		if not grid.editor_mode():
			return false
		if flush_undo:
			grid.push_empty_undo()
		var change := CellChange.new(i, j, pure().clone())
		if pure().put_block(corner):
			grid._push_undo_changes([change], false)
			grid.maybe_update_hints()
			return true
		return false
	func put_nowater(corner: E.Corner, flush_undo := true, flood := false, force_no_mix := false) -> bool:
		if flush_undo:
			grid.push_empty_undo()
		if !grid.is_corner_partially_valid(Content.NoWater, i, j, corner):
			return false
		if water_at(corner):
			remove_content(corner, false)
		var changes: Array[Change] = [CellChange.new(i, j, pure().clone())]
		if pure().put_nowater(corner, force_no_mix):
			# No auto-flooding nowater
			if flood:
				var dfs := AddNoWaterDfs.new(grid)
				dfs.flood(i, j, corner)
				changes.append_array(dfs.changes)
			grid._push_undo_changes(changes, false)
		grid.maybe_update_hints()
		return true
	func put_noboat(corner: E.Corner, flush_undo := true, force_no_mix := false) -> bool:
		if flush_undo:
			grid.push_empty_undo()
		if !grid.is_corner_partially_valid(Content.NoBoat, i, j, corner):
			return false
		if water_at(corner):
			return false
		var changes: Array[Change] = [CellChange.new(i, j, pure().clone())]
		if pure().put_noboat(corner, force_no_mix):
			grid._push_undo_changes(changes, false)
		grid.maybe_update_hints()
		return true
	func remove_content(corner: E.Corner, flush_undo := true) -> void:
		if block_at(corner) and not grid.editor_mode():
			return
		if flush_undo:
			grid.push_empty_undo()
		var changes: Array[Change] = []
		if water_at(corner):
			changes.append_array(grid._flood_water(i, j, corner, false).changes)
		var change := CellChange.new(i, j, pure().clone())
		if pure().put_nothing(corner):
			changes.append(change)
			# push undo changes before flooding
			grid._push_undo_changes(changes, false)
			# Removing block might trigger flooding
			if change.prev_cell.block_at(corner):
				grid.flood_all(false)
		else:
			grid._push_undo_changes(changes, false)
		grid.maybe_update_hints()
	func remove_nowater(corner: E.Corner, flush_undo := true) -> void:
		if pure()._content_at(corner) != Content.NoBoatWater:
			return remove_content(corner, flush_undo)
		put_noboat(corner, flush_undo, true)
	func remove_noboat(corner: E.Corner, flush_undo := true) -> void:
		if pure()._content_at(corner) != Content.NoBoatWater:
			return remove_content(corner, flush_undo)
		put_nowater(corner, flush_undo, false, true)
	func _change_wall(wall: E.Walls, new: bool, flush_undo: bool, unsafe_mode: bool) -> void:
		match wall:
			E.Top, E.Left, E.Right, E.Bottom:
				var c := WallChange.new(i, j, wall as E.Side, grid.wall_at(i, j, wall as E.Side))
				grid._change_wall(i, j, wall as E.Side, new)
				grid._push_undo_changes([c], flush_undo)
			E.Dec, E.Inc:
				var c := CellChange.new(i, j, pure().clone())
				pure()._change_diag_wall(wall as E.Diagonal, new)
				grid._push_undo_changes([c], flush_undo)
		if unsafe_mode:
			# No safety checks
			return
		if new:
			grid.fix_invalid_boats(false)
		else:
			# Removing walls might cause water to flood where it couldn't before
			# Optimization: We could just flood starting from around this cell
			grid.flood_all(false)
		grid.validate()
		grid.maybe_update_hints()
	func put_wall(wall: E.Walls, flush_undo := true, unsafe_mode := false) -> bool:
		_change_wall(wall, true, flush_undo, unsafe_mode)
		return true
	func remove_wall(wall: E.Walls, flush_undo := true) -> bool:
		_change_wall(wall, false, flush_undo, false)
		return true
	func put_boat(flush_undo := true, flood := false) -> bool:
		if flush_undo:
			grid.push_empty_undo()
		if wall_at(E.Walls.Bottom) or pure().cell_type() != E.Single:
			return false
		if !grid.is_corner_partially_valid(Content.Boat, i, j, E.Corner.TopRight):
			return false
		# Put water below if necessary
		var c := grid.get_cell(i + 1, j)
		if c.pure()._content_top() != Content.Water:
			if not c.put_water(E.diag_to_corner(c.cell_type(), E.Side.Top), false):
				return false
		var changes: Array[Change] = [CellChange.new(i, j, pure().clone())]
		if pure()._put_boat():
			if flood:
				var dfs := AddNoWaterDfs.new(grid)
				dfs.flood(i, j, E.Corner.TopLeft)
				changes.append_array(dfs.changes)
			grid._push_undo_changes(changes, false)
			grid.maybe_update_hints()
			return true
		return false
	func has_boat() -> bool:
		return pure()._has_boat()
	func cell_type() -> E.CellType:
		return pure().cell_type()
	func corners() -> Array[E.Corner]:
		return pure().corners()
	func water_would_flood_how_many(corner: E.Corner) -> float:
		if water_at(corner):
			return 0.0
		var dfs := AddWaterDfs.new(grid, i)
		dfs.dry_run = true
		dfs.flood(i, j, corner)
		return dfs.added_waters
	func water_would_flood_which(corner: E.Corner) -> Array[WaterPosition]:
		if water_at(corner):
			return []
		var dfs := AddWaterDfs.new(grid, i)
		dfs.dry_run = true
		dfs.flood(i, j, corner)
		return dfs.water_locs
	func boat_possible() -> bool:
		# TODO: Move that logic here
		return SolverModel._boat_possible(grid, i, j)
	func boat_would_flood_which() -> Array[WaterPosition]:
		if SolverModel._boat_possible(grid, i, j):
			var c := grid.get_cell(i + 1, j)
			return c.water_would_flood_which(E.diag_to_corner(c.cell_type(), E.Side.Top))
		else:
			assert(false, "Should be called only if possible")
			return []
	func nowater_would_flood_how_many(corner: E.Corner) -> float:
		if not nothing_at(corner):
			return 0.0
		var dfs := AddNoWaterDfs.new(grid)
		dfs.dry_run = true
		dfs.flood(i, j, corner)
		return dfs.added_nowater
		
	func _has_boat_invalid_pos() -> bool:
		return has_boat() and (wall_at(E.Walls.Bottom) or cell_type() != E.Single or grid.get_cell(i + 1, j).pure()._content_top() != Content.Water)

func rows() -> int:
	return n

func cols() -> int:
	return m

func _pure_cell(i: int, j: int) -> PureCell:
	return pure_cells[i][j]

func get_cell(i: int, j: int) -> CellModel:
	return CellWithLoc.new(i, j, self)

func _do_add_row(row: Array[PureCell], new_wall_bottom: Array[bool], new_wall_right: Array[bool], new_line_hint: LineHint) -> AddRowChange:
	assert(editor_mode())
	if row.is_empty():
		for _j in m:
			row.append(PureCell.empty())
	if new_wall_bottom.is_empty():
		new_wall_bottom.resize(m)
	if new_wall_right.is_empty():
		new_wall_right.resize(m - 1)
	n += 1
	pure_cells.append(row)
	wall_bottom.append(new_wall_bottom)
	wall_right.append(new_wall_right)
	_row_hints.append(new_line_hint)
	maybe_update_hints()
	validate()
	return AddRowChange.new()

func _do_rem_row() -> RemRowChange:
	assert(editor_mode())
	n -= 1
	var prev_row: Array[PureCell] = []
	var prev_wall_bottom: Array[bool] = []
	var prev_wall_right: Array[bool] = []
	# Why is this sometimes Array and not Array[PureCell]?
	prev_row.assign(pure_cells.pop_back())
	prev_wall_bottom.assign(wall_bottom.pop_back())
	prev_wall_right.assign(wall_right.pop_back())
	var hint: LineHint = _row_hints.pop_back()
	fix_invalid_boats(false)
	maybe_update_hints()
	validate()
	return RemRowChange.new(prev_row, prev_wall_bottom, prev_wall_right, hint)

func add_row(flush_undo := true) -> void:
	var change := _do_add_row([], [], [], _empty_line_hint())
	_push_undo_changes([change], flush_undo)
	flood_all(false)
	maybe_update_hints()
	validate()

func rem_row(flush_undo := true) -> void:
	if n == 1:
		return
	if flush_undo:
		push_empty_undo()
	var change := _do_rem_row()
	_push_undo_changes([change], false)

func _do_add_col(col: Array[PureCell], new_wall_bottom: Array[bool], new_wall_right: Array[bool], new_line_hint: LineHint) -> AddColChange:
	assert(editor_mode())
	if col.is_empty():
		for _i in n:
			col.append(PureCell.empty())
	if new_wall_bottom.is_empty():
		new_wall_bottom.resize(n - 1)
	if new_wall_right.is_empty():
		new_wall_right.resize(n)
	m += 1
	for i in n:
		pure_cells[i].append(col[i])
		if i != n - 1:
			wall_bottom[i].append(new_wall_bottom[i])
		wall_right[i].append(new_wall_right[i])
	_col_hints.append(new_line_hint)
	maybe_update_hints()
	validate()
	return AddColChange.new()

func _do_rem_col() -> RemColChange:
	assert(editor_mode())
	m -= 1
	var prev_col: Array[PureCell] = []
	var prev_wall_bottom: Array[bool] = []
	var prev_wall_right: Array[bool] = []
	for i in n:
		prev_col.append(pure_cells[i].pop_back().clone())
		if i != n - 1:
			prev_wall_bottom.append(wall_bottom[i].pop_back())
		prev_wall_right.append(wall_right[i].pop_back())
	var hint: LineHint = _col_hints.pop_back()
	maybe_update_hints()
	validate()
	return RemColChange.new(prev_col, prev_wall_bottom, prev_wall_right, hint)

func add_col(flush_undo := true) -> void:
	var change := _do_add_col([], [], [], _empty_line_hint())
	_push_undo_changes([change], flush_undo)
	flood_all(false)
	maybe_update_hints()
	validate()

func rem_col(flush_undo := true) -> void:
	if m == 1:
		return
	var change := _do_rem_col()
	_push_undo_changes([change], flush_undo)

func row_hints() -> Array[LineHint]:
	return _row_hints

func col_hints() -> Array[LineHint]:
	return _col_hints

func force_editor_mode(b := true) -> void:
	_force_editor_mode = b

# TODO: REMOVE
func get_expected_boats() -> int:
	return _grid_hints.total_boats

# TODO: REMOVE
func get_expected_waters() -> float:
	return _grid_hints.total_water

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
	return i == n - 1 or wall_bottom[i][j] or pure_cells[i][j]._content_bottom() == Content.Block or pure_cells[i + 1][j]._content_top() == Content.Block

func _has_wall_top(i: int, j: int) -> bool:
	return i == 0 or _has_wall_bottom(i - 1, j)

func _has_wall_right(i: int, j: int) -> bool:
	return j == m - 1 or wall_right[i][j] or pure_cells[i][j].c_right == Content.Block or pure_cells[i][j + 1].c_left == Content.Block

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

func editor_mode() -> bool:
	return _force_editor_mode or solution_c_left.is_empty()

func maybe_update_hints() -> void:
	if not editor_mode() or not auto_update_hints():
		return
	_grid_hints.total_boats = count_boats()
	_grid_hints.total_water = count_waters()
	_grid_hints.expected_aquariums = all_aquarium_counts()
	for i in n:
		_row_hints[i].boat_count = count_boat_row(i)
		var type := _is_together(_row_bools(i, Content.Boat))
		_row_hints[i].boat_count_type = type
		_row_hints[i].water_count = count_water_row(i)
		type = _is_together(_row_bools(i, Content.Water))
		_row_hints[i].water_count_type = type
	for j in m:
		_col_hints[j].boat_count = count_boat_col(j)
		var type := _is_together(_col_bools(j, Content.Boat))
		_col_hints[j].boat_count_type = type
		_col_hints[j].water_count = count_water_col(j)
		type = _is_together(_col_bools(j, Content.Water))
		_col_hints[j].water_count_type = type
	assert(are_hints_satisfied())

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
			return Content.NoWater
		'y':
			return Content.NoBoat
		'z':
			return Content.NoBoatWater
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
		Content.NoWater:
			return 'x'
		Content.NoBoat:
			return 'y'
		Content.NoBoatWater:
			return 'z'
		Content.Block:
			return '#'
		Content.Boat:
			return 'b'
	assert(false, "Unknown content")
	return '?'

func _validate_hint(c1: String, c2: String) -> int:
	c1 = _validate(c1, ".0123456789")
	c2 = _validate(c2, ".0123456789}-")
	if c1 != '.':
		if c2.is_valid_int():
			return int(c1 + c2)
		else:
			return int(c1)
	else:
		assert(c2 == "." or c2 == "}" or c2 == "-", "Invalid hint")
		return -1

func _validate_hint_float(c1: String, c2: String) -> float:
	var h := _validate_hint(c1, c2)
	if h == -1:
		return -1.
	else:
		return float(h) / 2.

func _validate_hint_type(c2: String) -> E.HintType:
	if c2 == '}':
		return E.HintType.Together
	elif c2 == '-':
		return E.HintType.Separated
	else:
		return E.HintType.Hidden

func _parse_extra_data(line: String) -> void:
	var kv := line.split("=", false, 2)
	match kv[0]:
		"+waters":
			_grid_hints.total_water = float(kv[1])
		"+boats":
			_grid_hints.total_boats = int(kv[1])
		"+aqua":
			var sv := kv[1].split(":", false, 2)
			_grid_hints.expected_aquariums[float(sv[0])] = int(sv[1])
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
	var hb := int(lines[0][0] == 'B')
	var hh := int(lines[hb][hb] == 'h')
	if hb == 1 and not content_only:
		for i in n:
			_row_hints[i].boat_count = _validate_hint(lines[2 * i + 1 + hh][0], lines[2 * i + 2 + hh][0])
			_row_hints[i].boat_count_type = _validate_hint_type(lines[2 * i + 2 + hh][0])
		for j in m:
			_col_hints[j].boat_count = _validate_hint(lines[0][2 * j + 1 + hh], lines[0][2 * j + 2 + hh])
			_col_hints[j].boat_count_type = _validate_hint_type(lines[0][2 * j + 2 + hh])
	if hh == 1 and not content_only:
		for i in n:
			_row_hints[i].water_count = _validate_hint_float(lines[2 * i + 1 + hb][hb], lines[2 * i + 2 + hb][hb])
			_row_hints[i].water_count_type = _validate_hint_type(lines[2 * i + 2 + hb][hb])
		for j in m:
			_col_hints[j].water_count = _validate_hint_float(lines[hb][2 * j + 1 + hb], lines[hb][2 * j + 2 + hb])
			_col_hints[j].water_count_type = _validate_hint_type(lines[hb][2 * j + 2 + hb])
	var h := hb + hh
	for i in n:
		for j in m:
			var c1 := _validate(lines[2 * i + h][2 * j + h], '.wxyzb#')
			var c2 := _validate(lines[2 * i + h][2 * j + 1 + h], '.wxyzb#')
			var c3 := _validate(lines[2 * i + 1 + h][2 * j + h], '.|_L')
			var c4 := _validate(lines[2 * i + 1 + h][2 * j + 1 + h], '.╲/')
			var cell := _pure_cell(i, j)
			if not content_only or cell.c_left != Content.Block:
				cell.c_left = _str_content(c1)
			if not content_only or cell.c_right != Content.Block:
				cell.c_right = _str_content(c2)
			if not content_only:
				if c4 == '╲':
					cell.type = E.CellType.DecDiag
				elif c4 == '/':
					cell.type = E.CellType.IncDiag
				else:
					cell.type = E.CellType.Single
				if i < n - 1:
					wall_bottom[i][j] = (c3 == '_' or c3 == 'L')
				if j > 0:
					wall_right[i][j - 1] = (c3 == '|' or c3 == 'L')
	flood_all()
	validate()
	_finish_loading(load_mode)

func _finish_loading(load_mode: LoadMode) -> void:
	undo_stack.clear()
	redo_stack.clear()
	if load_mode == GridModel.LoadMode.Solution or load_mode == GridModel.LoadMode.SolutionNoClear:
		assert(are_hints_satisfied(), "Invalid solution")
		solution_c_left.clear()
		solution_c_right.clear()
		for i in n:
			solution_c_left.append(pure_cells[i].map(func(c): return c.c_left))
			solution_c_right.append(pure_cells[i].map(func(c): return c.c_right))
		if load_mode != GridModel.LoadMode.SolutionNoClear:
			clear_content()
	auto_update_hints_ = load_mode == LoadMode.Editor
	maybe_update_hints()
	validate()

func set_auto_update_hints(b: bool) -> void:
	auto_update_hints_ = b
	if b:
		maybe_update_hints()

func auto_update_hints() -> bool:
	return editor_mode() and auto_update_hints_

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
	if _grid_hints.total_water != -1:
		builder.append("+waters=%.1f\n" % _grid_hints.total_water)
	if _grid_hints.total_boats != 0:
		builder.append("+boats=%d\n" % _grid_hints.total_boats)
	var boat_hints := _row_hints.any(func(h): return h.boat_count != -1) or _col_hints.any(func(h): return h.boat_count != -1)
	var hints := _row_hints.any(func(h): return h.water_count != -1.) or _col_hints.any(func(h): return h.water_count != -1.)
	if boat_hints:
		builder.append('B')
		if hints:
			builder.append('.')
		for j in m:
			builder.append(_col_hint(_col_hints[j].boat_count))
		builder.append('\n')
	if hints:
		if boat_hints:
			builder.append('.')
		builder.append('h')
		for j in m:
			builder.append(_col_hint(int(_col_hints[j].water_count * 2)))
		builder.append('\n')
	for i in n:
		if boat_hints:
			builder.append(_row_hint1(_row_hints[i].boat_count))
		if hints:
			builder.append(_row_hint1(int(_row_hints[i].water_count * 2)))
		for j in m:
			var cell := _pure_cell(i, j)
			builder.append(_content_str(cell.c_left))
			builder.append(_content_str(cell.c_right))
		builder.append("\n")
		if boat_hints:
			builder.append(_row_hint2(_row_hints[i].boat_count))
		if hints:
			builder.append(_row_hint2(int(_row_hints[i].water_count * 2)))
		for j in m:
			var left := _has_wall_left(i, j)
			var down := _has_wall_bottom(i, j)
			if left:
				builder.append("L" if down else "|")
			else:
				builder.append("_" if down else ".")
			var cell := _pure_cell(i, j)
			if cell.type == E.Single:
				builder.append(".")
			else:
				builder.append("╲" if cell.type == E.Dec else "/")
		builder.append("\n")
	return "".join(builder)

func _undo_impl(undos: Array[Changes], redos: Array[Changes], skip_empty: bool) -> bool:
	while skip_empty and not undos.is_empty() and (undos.back() as Changes).changes.is_empty():
		undos.pop_back()
	if undos.is_empty():
		return false
	var changes: Array[Change] = (undos.pop_back() as Changes).changes
	# We apply undo changes in reverse order. Specially relevant when a single
	# thing is changed more than once
	changes.reverse()
	for i in changes.size():
		changes[i] = changes[i].undo(self)

	# changes is now the changes to redo the undo
	redos.push_back(Changes.new(changes))
	# Floods should've gone in the undo stack
	assert(!flood_all(false))
	maybe_update_hints()
	return true

func push_empty_undo() -> void:
	_push_undo_changes([], true)

func undo(skip_empty := true) -> bool:
	return _undo_impl(undo_stack, redo_stack, skip_empty)

func redo(skip_empty := true) -> bool:
	# Beautifully, redo works exactly the same as undo
	return _undo_impl(redo_stack, undo_stack, skip_empty)

func _push_undo_changes(changes: Array[Change], flush_first: bool) -> void:
	redo_stack.clear()
	while flush_first and not undo_stack.is_empty() and (undo_stack.back() as Changes).changes.is_empty():
		undo_stack.pop_back()
	if flush_first or undo_stack.is_empty():
		undo_stack.push_back(Changes.new(changes))
	else:
		(undo_stack.back() as Changes).changes.append_array(changes)

# Returns Array[(i, j, E.Walls)] a list of walls defined by these vertices.
func _idx_to_cell_wall(i1: int, j1: int, i2: int, j2: int) -> Array[Vector3i]:
	if mini(i1, i2) < 0 or min(j1, j2) < 0 or maxi(i1, i2) > n or maxi(j1, j2) > m:
		return []
	var ans: Array[Vector3i] = []
	# horizontal
	if i1 == i2:
		for j in range(mini(j1, j2), maxi(j1, j2)):
			if i1 == 0:
				ans.append(Vector3i(i1, j, E.Walls.Top))
			else:
				ans.append(Vector3i(i1 - 1, j, E.Walls.Bottom))
	# vertical
	elif j1 == j2:
		for i in range(mini(i1, i2), maxi(i1, i2)):
			if j1 == 0:
				ans.append(Vector3i(i, j1, E.Walls.Left))
			else:
				ans.append(Vector3i(i, j1 - 1, E.Walls.Right))
	# inc diag
	elif (i2 - i1) == (j1 - j2):
		var j := maxi(j1, j2)
		for i in range(mini(i1, i2), maxi(i1, i2)):
			j -= 1
			ans.append(Vector3i(i, j, E.Walls.IncDiag))
	# dec diag
	elif (i2 - i1) == (j2 - j1):
		var j := mini(j1, j2)
		for i in range(mini(i1, i2), maxi(i1, i2)):
			ans.append(Vector3i(i, j, E.Walls.DecDiag))
			j += 1
	#invalid
	else:
		pass
	return ans

func put_wall_from_idx(i1: int, j1: int, i2: int, j2: int, flush_undo := true) -> bool:
	if flush_undo:
		push_empty_undo()
	var walls := _idx_to_cell_wall(i1, j1, i2, j2)
	if walls.is_empty():
		return false
	for cw in walls:
		get_cell(cw.x, cw.y).put_wall(cw.z, false)
	return true

# Same as above but removes. Ignores walls that don't exist, returns false only if
# vertices are invalid.
func remove_wall_from_idx(i1: int, j1: int, i2: int, j2: int, flush_undo := true) -> bool:
	if flush_undo:
		push_empty_undo()
	var walls := _idx_to_cell_wall(i1, j1, i2, j2)
	if walls.is_empty():
		return false
	for cw in walls:
		get_cell(cw.x, cw.y).remove_wall(cw.z, false)
	return true

func _flood_water(i: int, j: int, corner: E.Corner, add: bool) -> Dfs:
	if add:
		var dfs := AddWaterDfs.new(self, i)
		dfs.flood(i, j, corner)
		return dfs
	else:
		var dfs := RemoveWaterDfs.new(self, i)
		dfs.flood(i, j, corner)
		return dfs

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
		var keep_going := self._cell_logic(i, j, corner, cell)
		if !cell.eq(prev_cell):
			changes.append(CellChange.new(i, j, prev_cell))
		if not keep_going:
			return
		var is_left := E.corner_is_left(corner)
		var is_top := E.corner_is_top(corner)
		# Try to flood left
		if !grid._has_wall_left(i, j) and !(cell.type != E.Single and !is_left):
			flood(i, j - 1, E.diag_to_corner(grid._pure_cell(i, j - 1).type, E.Side.Right))
		# Try to flood right
		if !grid._has_wall_right(i, j) and !(cell.type != E.Single and is_left):
			flood(i, j + 1, E.diag_to_corner(grid._pure_cell(i, j + 1).type, E.Side.Left))
		# Try to flood down
		if !grid._has_wall_bottom(i, j) and !(cell.type != E.Single and is_top) and _can_go_down(i, j):
			flood(i + 1, j, E.diag_to_corner(grid._pure_cell(i + 1, j).type, E.Side.Top))
		# Try to flood up, if gravity helps
		if !grid._has_wall_top(i, j) and !(cell.type != E.Single and !is_top) and _can_go_up(i, j):
			flood(i - 1, j, E.diag_to_corner(grid._pure_cell(i - 1, j).type, E.Side.Bottom))

class AddWaterDfs extends Dfs:
	# Water can go up to level min_i because of physics
	var min_i: int
	var added_waters := 0.0
	var dry_run := false
	var water_locs: Array[WaterPosition]
	func _init(grid_: GridImpl, min_i_: int) -> void:
		super(grid_)
		min_i = min_i_
	func _cell_logic(i: int, j: int, corner: E.Corner, cell: PureCell) -> bool:
		var c := cell._content_at(corner)
		match c:
			Content.Nothing, Content.NoWater, Content.Boat, Content.Water:
				var pos: E.Waters = E.Waters.Single if cell.cell_type() == E.CellType.Single else (corner as E.Waters)
				if c != Content.Water:
					added_waters += E.waters_size(pos)
					if dry_run:
						water_locs.append(WaterPosition.new(i, j, pos))
				if not dry_run:
					cell.put_water(corner)
			Content.Block:
				return false
		return true
	func _can_go_up(i: int, _j: int) -> bool:
		return i - 1 >= min_i
	func _can_go_down(_i: int, _j: int) -> bool:
		return true


class AddNoWaterDfs extends Dfs:
	var added_nowater := 0.0
	var dry_run := false
	func _cell_logic(_i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		var c := cell._content_at(corner)
		match c:
			Content.Water, Content.Nothing, Content.NoWater:
				if c != Content.NoWater:
					if cell.cell_type() == E.CellType.Single:
						added_nowater += 1.0
					else:
						added_nowater += 0.5
				if not dry_run:
					cell.put_nowater(corner, false)
		return true
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	# TODO: This is incomplete, because we need to move down through water to other "tunnels"
	# But it's hard because we need to be careful about buckets, so let's be conservative
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
	func _cell_logic(_i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		water_count += cell._content_count_from(Content.Water, corner)
		return true
	# Walk whole aquarium
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	func _can_go_down(_i: int, _j: int) -> bool:
		return true


func grid_hints() -> GridHints:
	return _grid_hints

func all_aquarium_counts() -> Dictionary:
	var dfs := CountWaterDfs.new(self)
	var counts: Dictionary = {}
	for i in n:
		for j in m:
			for corner in E.Corner.values():
				var c := _pure_cell(i, j)
				if c._valid_corner(corner) and c.last_seen(corner) < last_seen and not c.block_at(corner):
					dfs.water_count = 0
					dfs.flood(i, j, corner)
					counts[dfs.water_count] = counts.get(dfs.water_count, 0) + 1
	return counts

func aquarium_hints_status() -> E.HintStatus:
	var aqs := all_aquarium_counts()
	for hint_size in _grid_hints.expected_aquariums:
		var hint_count: int = _grid_hints.expected_aquariums[hint_size]
		if hint_count != -1 and hint_count != aqs.get(hint_size, 0):
			return E.HintStatus.Normal
	return E.HintStatus.Satisfied


func count_nowater_row(i : int) -> float:
	var count: float = 0.
	for j in m:
		count += _pure_cell(i, j).nowater_count()
	return count


func count_water_row(i: int) -> float:
	var count: float = 0.
	for j in m:
		count += _pure_cell(i, j).water_count()
	return count

func count_water_col(j: int) -> float:
	var count: float = 0.
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


func count_nowaters() -> float:
	var count := 0.0
	for i in n:
		count += count_nowater_row(i)
	return count


func _hint_statusf(count: float, hint: float) -> E.HintStatus:
	if hint == -1 or count == hint:
		return E.HintStatus.Satisfied
	elif count > hint:
		return E.HintStatus.Wrong
	else:
		return E.HintStatus.Normal

func _hint_statusi(count: int, hint: int) -> E.HintStatus:
	return _hint_statusf(float(count), float(hint))

func all_boats_hint_status() -> E.HintStatus:
	return _hint_statusi(count_boats(), get_expected_boats())

func all_waters_hint_status() -> E.HintStatus:
	return _hint_statusf(count_waters(), get_expected_waters())

func merge_status(status1: E.HintStatus, status2: E.HintStatus) -> E.HintStatus:
	if status1 == E.HintStatus.Wrong or status2 == E.HintStatus.Wrong:
		return E.HintStatus.Wrong
	if status1 == E.HintStatus.Normal or status2 == E.HintStatus.Normal:
		return E.HintStatus.Normal
	return E.HintStatus.Satisfied

func all_hints_status() -> E.HintStatus:
	var s := E.HintStatus.Satisfied
	#print("bef ", E.HintStatus.find_key(s))
	s = merge_status(s, all_boats_hint_status())
	#print("boats ", E.HintStatus.find_key(s))
	s = merge_status(s, all_waters_hint_status())
	#print("waters ", E.HintStatus.find_key(s))
	s = merge_status(s, aquarium_hints_status())
	#print("aquariums ", E.HintStatus.find_key(s))
	for i in n:
		s = merge_status(s, get_row_hint_status(i, E.HintContent.Water))
		s = merge_status(s, get_row_hint_status(i, E.HintContent.Boat))
		#print("row %d " % i, E.HintStatus.find_key(s))
	for j in m:
		s = merge_status(s, get_col_hint_status(j, E.HintContent.Water))
		s = merge_status(s, get_col_hint_status(j, E.HintContent.Boat))
		#print("col %d " % j, E.HintStatus.find_key(s))
	return s

func check_complete() -> bool:
	for i in n:
		for j in m:
			var c := _pure_cell(i, j)
			if c._content_left() == Content.Nothing or c._content_right() == Content.Nothing:
				return false
	return true

func are_hints_satisfied(check_complete_ := false) -> bool:
	if check_complete_ and not check_complete():
		return false
	return all_hints_status() == E.HintStatus.Satisfied

func is_any_hint_broken() -> bool:
	return all_hints_status() == E.HintStatus.Wrong

enum IsTogether { Separate, Together, Zero }

# Any if there are 0 true's
func _is_together(a: Array[bool]) -> E.HintType:
	var i := 0
	while i < a.size() and not a[i]:
		i += 1
	if i == a.size():
		return E.HintType.Zero
	while i < a.size() and a[i]:
		i += 1
	while i < a.size() and not a[i]:
		i += 1
	return E.HintType.Together if i == a.size() else E.HintType.Separated


func _hint_type_ok(hint: E.HintType, a: Array[bool]) -> bool:
	if hint == E.HintType.Hidden:
		return true
	var is_together := _is_together(a)
	return is_together == hint

func _status_and_then(status: E.HintStatus, together_match: bool, is_question_mark: bool) -> E.HintStatus:
	if status == E.HintStatus.Satisfied and not together_match:
		if is_question_mark:
			return E.HintStatus.Normal
		else:
			return E.HintStatus.Wrong
	return status

func _row_bools(i: int, content: Content) -> Array[bool]:
	var a: Array[bool] = []
	for j in m:
		a.append(_pure_cell(i, j)._content_left() == content)
		a.append(_pure_cell(i, j)._content_right() == content)
	return a

func _col_bools(j: int, content: Content) -> Array[bool]:
	var a: Array[bool] = []
	for i in n:
		a.append(_pure_cell(i, j)._content_top() == content)
		a.append(_pure_cell(i, j)._content_bottom() == content)
	return a
	
func get_row_hint_status(i : int, hint_content : E.HintContent) -> E.HintStatus:
	match hint_content:
		E.HintContent.Boat:
			var count := _row_hints[i].boat_count
			var status := _hint_statusi(count_boat_row(i), count)
			var type :=  _hint_type_ok(_row_hints[i].boat_count_type, _row_bools(i, Content.Boat))
			return _status_and_then(status, type, count == -1)
		E.HintContent.Water:
			var count := _row_hints[i].water_count
			var status := _hint_statusf(count_water_row(i), count)
			var type := _hint_type_ok(_row_hints[i].water_count_type, _row_bools(i, Content.Water))
			return _status_and_then(status, type, count == -1.0)
		_:
			assert(false, "Bad content")
			return E.HintStatus.Wrong

func get_col_hint_status(j : int, hint_content : E.HintContent) -> E.HintStatus:
	match hint_content:
		E.HintContent.Boat:
			var count := _col_hints[j].boat_count
			var status := _hint_statusi(count_boat_col(j), count)
			var type := _hint_type_ok(_col_hints[j].boat_count_type, _col_bools(j, Content.Boat))
			return _status_and_then(status, type, count == -1)
		E.HintContent.Water:
			var count := _col_hints[j].water_count
			var status := _hint_statusf(count_water_col(j), count)
			var type := _hint_type_ok(_col_hints[j].water_count_type, _col_bools(j, Content.Water))
			return _status_and_then(status, type, count == -1.0)
		_:
			assert(false, "Bad content")
			return E.HintStatus.Wrong

# Use when level is created with with_solution
func is_solution_partially_valid() -> bool:
	assert(!editor_mode() or n == 0)
	for i in n:
		for j in m:
			if not _is_content_partial_solution(_pure_cell(i, j).c_left, solution_c_left[i][j]):
				return false
			if not _is_content_partial_solution(_pure_cell(i, j).c_right, solution_c_right[i][j]):
				return false
	return true

func is_corner_partially_valid(c: Content, i: int, j: int, corner: E.Corner) -> bool:
	return editor_mode() or _is_content_partial_solution(c, _content_sol(i, j, corner))

func validate_hint(count: float, type: E.HintType) -> void:
	if count != -1 and type != E.HintType.Hidden:
		assert((count == 0) == (type == E.HintType.Zero))
	# Never have a hidden count with Zero type. Theoretically it's ok, but it's unclear
	# to the user and the solver doesn't handle it well.
	assert(count != -1 or type != E.HintType.Zero or editor_mode())

func validate() -> void:
	if not OS.is_debug_build():
		return
	for j in m:
		validate_hint(col_hints()[j].boat_count, col_hints()[j].boat_count_type)
		validate_hint(col_hints()[j].water_count, col_hints()[j].water_count_type)
	for i in n:
		validate_hint(row_hints()[i].boat_count, row_hints()[i].boat_count_type)
		validate_hint(row_hints()[i].water_count, row_hints()[i].water_count_type)
	# Blocks are surrounded by walls
	for i in n:
		for j in m:
			var cell := _pure_cell(i, j)
			if (cell._content_left() == Content.Block) != (cell._content_right() == Content.Block):
				assert(cell.type != E.Single)
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
				assert(_pure_cell(i, j).type == E.Single)
				assert(i < n - 1 and _pure_cell(i + 1, j)._content_top() == Content.Water)

func flood_all(flush_undo := true) -> bool:
	var dfs := AddWaterDfs.new(self, 0)
	# Top down is important for correctness
	for i in n:
		for j in m:
			var c := _pure_cell(i, j)
			for corner in E.Corner.values():
				if c.last_seen(corner) < last_seen and c.water_at(corner):
					dfs.min_i = i
					dfs.flood(i, j, corner)
	if flush_undo:
		push_empty_undo()
	if !dfs.changes.is_empty():
		_push_undo_changes(dfs.changes, false)
	return fix_invalid_boats(false) or !dfs.changes.is_empty()

func fix_invalid_boats(flush_undo := true) -> bool:
	if flush_undo:
		push_empty_undo()
	var removed_boat := false
	for i in n:
		for j in m:
			var c := get_cell(i, j)
			if c._has_boat_invalid_pos():
				c.remove_content(E.Corner.TopLeft, false)
				removed_boat = true
	return removed_boat

func flood_nowater(flush_undo := true) -> bool:
	if flush_undo:
		push_empty_undo()
	var dfs := AddNoWaterDfs.new(self)
	for i in range(n - 1, -1, -1):
		for j in m:
			var c := _pure_cell(i, j)
			for corner in E.Corner.values():
				if c.last_seen(corner) < last_seen and c.nowater_at(corner):
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
	undo_stack.clear()
	redo_stack.clear()

func clear_all() -> void:
	if not editor_mode():
		return clear_content()
	for i in n:
		for j in m:
			pure_cells[i][j] = PureCell.empty()
			if i < n - 1:
				wall_bottom[i][j] = false
			if j < m - 1:
				wall_right[i][j] = false
	undo_stack.clear()
	redo_stack.clear()
	maybe_update_hints()

func export_data() -> Dictionary:
	return GridExporter.new().export_data(self)

func _line_hint_eq(a: LineHint, b: LineHint) -> bool:
	if a.boat_count != b.boat_count or a.boat_count_type != b.boat_count_type:
		return false
	if a.water_count != b.water_count or a.water_count_type != b.water_count_type:
		return false
	return true

func equal(other: GridImpl) -> bool:
	if n != other.n or m != other.m:
		return false
	for i in n:
		for j in m:
			if not _pure_cell(i, j).equal(other._pure_cell(i, j)):
				return false
	if _grid_hints.total_boats != other._grid_hints.total_boats:
		return false
	if _grid_hints.total_water != other._grid_hints.total_water:
		return false
	if _grid_hints.expected_aquariums != other._grid_hints.expected_aquariums:
		return false
	for i in n - 1:
		if wall_bottom[i] != other.wall_bottom[i]:
			return false
	for i in n:
		if wall_right[i] != other.wall_right[i]:
			return false
	for i in n:
		if not _line_hint_eq(_row_hints[i], other._row_hints[i]):
			return false
	for j in m:
		if not _line_hint_eq(_col_hints[j], other._col_hints[j]):
			return false
	return true
	
func is_empty() -> bool:
	return count_boats() <= 0 and count_waters() <= 0 and count_nowaters() <= 0

func copy_to_clipboard() -> void:
	var s = JSON.stringify(export_data())
	DisplayServer.clipboard_set(s)

func merge_last_undo() -> void:
	while not undo_stack.is_empty() and (undo_stack.back() as Changes).changes.is_empty():
		undo_stack.pop_back()
	if undo_stack.size() < 2:
		return
	var last: Changes = undo_stack.pop_back()
	(undo_stack.back() as Changes).changes.append_array(last.changes)

func _any_sol_boats() -> bool:
	for i in n:
		for j in m:
			if solution_c_left[i][j] == Content.Boat:
				return true
	return false

func prettify_hints() -> void:
	assert(not editor_mode())
	for i in n:
		var diags := false
		for j in m:
			if _pure_cell(i, j).cell_type() != E.Single:
				diags = true
				break
		if diags and _row_hints[i].water_count == 0.5:
			_row_hints[i].water_count_type = E.HintType.Hidden
		if not diags and _row_hints[i].water_count == 1:
			_row_hints[i].water_count_type = E.HintType.Hidden
		if _row_hints[i].water_count == m:
			_row_hints[i].water_count_type = E.HintType.Hidden
		if _row_hints[i].boat_count == 1 or _row_hints[i].boat_count == m:
			_row_hints[i].boat_count_type = E.HintType.Hidden
		
	for j in m:
		var diags := false
		for i in n:
			if _pure_cell(i, j).cell_type() != E.Single:
				diags = true
				break
		if diags and _col_hints[j].water_count == 0.5:
			_col_hints[j].water_count_type = E.HintType.Hidden
		if not diags and _col_hints[j].water_count == 1:
			_col_hints[j].water_count_type = E.HintType.Hidden
		if _col_hints[j].water_count == n:
			_col_hints[j].water_count_type = E.HintType.Hidden
	if not _any_sol_boats():
		grid_hints().total_boats = 0
		for hints in [row_hints(), col_hints()]:
			for h in hints:
				h.boat_count = -1
				h.boat_count_type = E.HintType.Hidden
	else:
		# 0 hint but there's no boat possible, let's remove it to make it prettier
		for i in n:
			if _row_hints[i].boat_count == 0 and not range(m).any(func(j): return SolverModel._boat_possible(self, i, j)):
				_row_hints[i].boat_count = -1
		for j in m:
			if _col_hints[j].boat_count == 0 and not range(n).any(func(i): return SolverModel._boat_possible(self, i, j)):
				_col_hints[j].boat_count = -1

func any_schrodinger_boats() -> bool:
	if _grid_hints.total_boats == -1:
		for i in n:
			if _row_hints[i].boat_count != -1:
				continue
			for j in m:
				# We can freely remove or add a boat on this cell and the solution remains valid
				if _col_hints[j].boat_count == -1 and SolverModel._boat_possible(self, i, j):
					return true
	return false
