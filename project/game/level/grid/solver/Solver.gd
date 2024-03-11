class_name SolverModel

const Content := GridImpl.Content

static func _maybe_infer_hint(grid: GridImpl, hints: Array[GridModel.LineHint], a: int, is_row: bool) -> GridModel.LineHint:
	var h := hints[a]
	if h.water_count == -1 and grid.grid_hints().total_water != -1:
		var inferred := grid.grid_hints().total_water
		for b in hints.size():
			if b != a:
				if hints[b].water_count == -1:
					inferred = -1
					break
				inferred -= hints[b].water_count
		if inferred != -1:
			h = h.duplicate()
			h.water_count = inferred
	if h.boat_count == -1 and not is_row and h.boat_count_type == E.HintType.Together:
		if h == hints[a]:
			h = h.duplicate()
		h.boat_count = 1
	if h.boat_count == -1 and grid.grid_hints().total_boats != -1:
		var inferred := grid.grid_hints().total_boats
		for b in hints.size():
			if b != a:
				if hints[b].boat_count == -1:
					inferred = -1
					break
				inferred -= hints[b].boat_count
		if inferred != -1 and h == hints[a]:
			h = h.duplicate()
		if inferred != -1:
			h.boat_count = inferred
	return h

static func _row_hint(grid: GridImpl, i: int) -> GridModel.LineHint:
	return _maybe_infer_hint(grid, grid.row_hints(), i, true)

static func _col_hint(grid: GridImpl, j: int) -> GridModel.LineHint:
	return _maybe_infer_hint(grid, grid.col_hints(), j, false)

class Strategy:
	var grid: GridImpl
	func _init(grid_: GridImpl) -> void:
		grid = grid_
	func apply_any() -> bool:
		return GridModel.must_be_implemented()
	func description() -> String:
		return "No description"


class FullPropagateNoWater extends Strategy:
	func description() -> String:
		return "Propagate NoWater even through walls (in upper caves)."
	func apply_any() -> bool:
		var dfs := AddNoWaterThroughDips.new(grid)
		# Bottom up for correctness
		for i in range(grid.rows() - 1, -1, -1):
			for j in grid.cols():
				var c := grid._pure_cell(i, j)
				for corner in c.corners():
					var cont := c._content_at(corner)
					if cont == Content.NoWater or cont == Content.NoBoatWater:
						# Reset last seen for this cell only, because we sometimes want to visit
						# them again if they can go down again
						c.set_last_seen(corner, 0)
						dfs.reset(i)
						dfs.flood(i, j, corner)
		grid._push_undo_changes(dfs.changes, false)
		return not dfs.changes.is_empty()


# This doesn't actually fully propagates NoWater, but it does if applied multiple times properly
class AddNoWaterThroughDips extends GridImpl.Dfs:
	# Can only go down when already at min_i
	var min_i: int
	var any: bool
	func reset(min_i_: int) -> void:
		min_i = min_i_
		any = false
	func _cell_logic(i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		var c := cell._content_at(corner)
		match c:
			Content.Nothing, Content.NoBoat:
				if i <= min_i:
					cell.put_nowater(corner, false)
					any = true
			Content.Block, Content.Boat, Content.NoWater, Content.NoBoatWater, Content.Water:
				pass
			_:
				assert(false, "Unkown content %d" % c)
		return true
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	func _can_go_down(i: int, _j: int) -> bool:
		return i >= min_i

# Strategy for a single row
class RowStrategy extends Strategy:
	# values is an array of component, that is, all triangles
	# are in the same aquarium. Each of the triangles in the component MUST be
	# flooded all at once with water or nowater. Each distinct componene IS completely
	# independent.
	func _apply_strategy(_i: int, _values: Array[RowComponent], _water_left: float, _nothing_left: float) -> bool:
		return GridModel.must_be_implemented()
	func _apply(i: int) -> bool:
		var water_hint := SolverModel._row_hint(grid, i).water_count
		if water_hint < 0:
			return false
		var dfs := RowDfs.new(i, grid)
		var last_seen := grid.last_seen
		var comps: Array[RowComponent] = []
		for j in grid.cols():
			# Deliberately going from left to right
			for corner in [E.TopLeft, E.BottomLeft, E.TopRight, E.BottomRight]:
				var cell := grid._pure_cell(i, j)
				if cell.last_seen(corner) < grid.last_seen and cell._valid_corner(corner) and cell.nothing_at(corner):
					dfs.comp = RowComponent.new(grid.get_cell(i, j), corner)
					dfs.flood(i, j, corner)
					if dfs.comp.size > 0:
						comps.append(dfs.comp)
		var nothing_left := 0.
		for j in grid.cols():
			nothing_left += grid._pure_cell(i, j).nothing_count()
		var water_left := water_hint - grid.count_water_row(i)
		if nothing_left == 0 or comps.size() == 0 or water_left > nothing_left or water_left < 0:
			return false
		return self._apply_strategy(i, comps, water_left, nothing_left)
	func apply_any() -> bool:
		var any := false
		for i in grid.rows():
			if self._apply(i):
				any = true
		return any

class RowComponent:
	var size := 0.
	var first: GridImpl.CellWithLoc
	var corner: E.Corner
	func _init(first_: GridImpl.CellWithLoc, corner_: E.Corner) -> void:
		first = first_
		corner = corner_
	func put_water() -> void:
		first.put_water(corner, false)
	func put_nowater() -> void:
		first.put_nowater(corner, false, true)

class RowDfs extends GridImpl.Dfs:
	var row_i: int
	var comp: RowComponent
	func _init(i: int, grid_: GridImpl) -> void:
		super(grid_)
		row_i = i
	func _cell_logic(i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		if cell.block_at(corner) or cell.nowater_at(corner):
			return false
		if i == row_i and !cell.water_at(corner):
			comp.size += (1 + int(cell.type == E.Single)) * 0.5
		return true
	func _can_go_up(i: int, _j: int) -> bool:
		return i > row_i
	func _can_go_down(_i: int, _j: int) -> bool:
		return true

# Strategy for a single column
class ColumnStrategy extends Strategy:
	# values is an array of component, that is, all triangles
	# are in the same aquarium. Each of the triangles in the component MUST be
	# flooded in order water or nowater. Each distinct componene MAY BE dependent.
	func _apply_strategy(_values: Array[ColComponent], _water_left: float, _nothing_left: float) -> bool:
		return GridModel.must_be_implemented()
	func _apply(j: int) -> bool:
		var hint := SolverModel._col_hint(grid, j).water_count
		if hint < 0:
			return false
		var dfs := ColDfs.new(j, grid)
		var last_seen := grid.last_seen
		var comps: Array[ColComponent] = []
		# Down to up because of our DFS
		for i in range(grid.rows() - 1, -1, -1):
			for corner in E.Corner.values():
				var cell := grid._pure_cell(i, j)
				if cell.last_seen(corner) < grid.last_seen and cell._valid_corner(corner) and cell.nothing_at(corner):
					dfs.comp = ColComponent.new()
					dfs.flood(i, j, corner)
					if dfs.comp.size > 0:
						# Just in case it's not already sorted because the DFS visited it in a
						# weird order
						dfs.comp.cells.sort_custom(func(c1, c2): return c1.i > c2.i)
						comps.append(dfs.comp)
		var nothing_left := 0.
		for i in grid.rows():
			nothing_left += grid._pure_cell(i, j).nothing_count()
		var water_left := hint - grid.count_water_col(j)
		if nothing_left == 0 or comps.size() == 0 or water_left > nothing_left or water_left < 0:
			return false
		return self._apply_strategy(comps, water_left, nothing_left)
	func apply_any() -> bool:
		var any := false
		for j in grid.cols():
			if self._apply(j):
				any = true
		return any

class CellPosition:
	var i: int
	var j: int
	var corner: E.Corner
	func _init(i_: int, j_: int, corner_: E.Corner) -> void:
		i = i_
		j = j_
		corner = corner_

class ColComponent:
	var size := 0.
	# Must be filled with water from left to right and nowater from right to left
	var cells: Array[CellPosition]
	func put_water_on(grid: GridImpl, count: float) -> void:
		for c in cells:
			count -= grid._pure_cell(c.i, c.j)._content_count_from(Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				grid.get_cell(c.i, c.j).put_water(c.corner, false)
				return
	func put_nowater_on(grid: GridImpl, count: float) -> void:
		for i in cells.size():
			var c: CellPosition = cells[-1 - i]
			count -= grid._pure_cell(c.i, c.j)._content_count_from(Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				(grid.get_cell(c.i, c.j) as GridImpl.CellWithLoc).put_nowater(c.corner, false, true)
				return

class ColDfs extends GridImpl.Dfs:
	var col_j: int
	var comp: ColComponent
	func _init(j: int, grid_: GridImpl) -> void:
		super(grid_)
		col_j = j
	func _cell_logic(i: int, j: int, corner: E.Corner, cell: PureCell) -> bool:
		if cell.block_at(corner) or cell.nowater_at(corner):
			return false
		var nothing := cell._content_count_from(Content.Nothing, corner)
		if j == col_j and nothing > 0:
			comp.size += nothing
			comp.cells.append(CellPosition.new(i, j, corner))
		return true
	func _can_go_up(_i: int, _j: int) -> bool:
		return true
	# Going down implies hitting buckets, which do not uphold the ColComponent invariant
	# of NEEDING to be done all in order. This is a simplification, and can be expanded.
	# An "easy" expansion is to first go all the way down, then go up and never down again.
	# This gets more correct cases, but still doesn't deal with the more complex problems
	# of buckets.
	func _can_go_down(_i: int, _j: int) -> bool:
		return false


class BasicRowStrategy extends RowStrategy:
	func description() -> String:
		return """
		- Put nowater in components that are too big
		- Put water everywhere if there's no more space for nowater
		"""
	func _apply_strategy(_i: int, values: Array[RowComponent], water_left: float, nothing_left: float) -> bool:
		if water_left == nothing_left:
			for comp in values:
				comp.put_water()
			return true
		var any := false
		for comp in values:
			if comp.size > water_left:
				comp.put_nowater()
				any = true
		return any

class MediumRowStrategy extends RowStrategy:
	func description() -> String:
		return "If a component is so big it MUST be filled, fill it."
	func _apply_strategy(_i: int, values: Array[RowComponent], water_left: float, nothing_left: float) -> bool:
		var any := false
		for comp in values:
			if comp.size <= water_left and (nothing_left - comp.size) < water_left:
				comp.put_water()
				any = true
		return any

class AdvancedRowStrategy extends RowStrategy:
	func description() -> String:
		return "Use subset sum to tell if some components MUST or CANT be present in the solution"
	func _apply_strategy(_i:int, values: Array[RowComponent], water_left: float, _nothing_left: float) -> bool:
		var numbers: Array[float] = []
		var size_to_cmp: Dictionary = {}
		for c in values:
			numbers.append(c.size)
			var cmps = size_to_cmp.get(c.size, [])
			cmps.append(c)
			size_to_cmp[c.size] = cmps
		var any := false
		for size in size_to_cmp:
			var new = numbers.duplicate()
			# Remove only one size
			new.erase(size)
			# If removing a single size made it impossible, all MUST be used
			if not SubsetSum.can_be_solved(water_left, new):
				for cmp in size_to_cmp[size]:
					cmp.put_water()
				any = true
			# If using a single size made it impossible, all CANT be used
			elif not SubsetSum.can_be_solved(water_left - size, new):
				for cmp in size_to_cmp[size]:
					cmp.put_nowater()
				any = true
		return any


class BasicColStrategy extends ColumnStrategy:
	func description() -> String:
		return """
		- Put nowater partially in components that are bigger than the hint
		- Put water everywhere if there's no more space for non-water
		"""
	func _apply_strategy(values: Array[ColComponent], water_left: float, nothing_left: float) -> bool:
		if water_left == nothing_left:
			for comp in values:
				comp.put_water_on(grid, comp.size)
			return true
		var any := false
		for comp in values:
			if comp.size > water_left:
				comp.put_nowater_on(grid, comp.size - water_left)
				any = true
		return any

class MediumColStrategy extends ColumnStrategy:
	func description() -> String:
		return "If a component is so big it MUST be partially filled, fill it."
	func _apply_strategy(values: Array[ColComponent], water_left: float, nothing_left: float) -> bool:
		var any := false
		for comp in values:
			if nothing_left - comp.size < water_left:
				comp.put_water_on(grid, water_left - (nothing_left - comp.size))
				any = true
		return any

class AdvancedColStrategy extends ColumnStrategy:
	func _apply(j: int) -> bool:
		var hint := SolverModel._col_hint(grid, j).water_count
		if hint <= 0:
			return false
		var water_left := hint - grid.count_water_col(j)
		if water_left <= 0:
			return false
		var single_i := -1
		var single_corner := E.Corner.TopLeft
		for i in grid.rows():
			var c := grid.get_cell(i, j)
			if c.cell_type() != E.CellType.Single:
				for corner in c.corners():
					if c.nothing_at(corner):
						if single_i == -1:
							single_i = i
							single_corner = corner
						else:
							single_i = -2
		if single_i >= 0:
			if water_left - floorf(water_left) == 0.5:
				return grid.get_cell(single_i, j).put_water(single_corner, false)
			else:
				return grid.get_cell(single_i, j).put_nowater(single_corner, false, true)
		return false
	func description() -> String:
		return "- If there's a single empty half-cell in the column, determine if it's water or nowater."


static func _maybe_extra_boat_col(grid: GridImpl, j: int) -> bool:
	var hint := SolverModel._col_hint(grid, j).boat_count
	return hint == -1 or grid.count_boat_col(j) < hint

class BoatRowStrategy extends RowStrategy:
	func description() -> String:
		return "If hint is all possible boat locations, then put the boats"
	func _apply(i: int) -> bool:
		var full_hint := SolverModel._row_hint(grid, i)
		var hint := full_hint.boat_count
		if hint == -1:
			if full_hint.boat_count_type == E.HintType.Together:
				hint = 1
				# If there are already multiple boats, let's make sure {} is satisfied.
				var first_boat := -1
				var last_boat := -1
				for j in grid.cols():
					if grid.get_cell(i, j).has_boat():
						last_boat = j
						if first_boat == -1:
							first_boat = j
				if first_boat != -1:
					var any := false
					for j in range(first_boat, last_boat + 1):
						var c := grid.get_cell(i, j)
						if not c.has_boat():
							if c.boat_possible() and SolverModel._maybe_extra_boat_col(grid, j):
								if c.put_boat(false, true):
									any = true
							else:
								# Impossible
								return false
					if any:
						return true
			elif full_hint.boat_count_type == E.HintType.Separated:
				hint = 2
		if hint <= 0:
			return false
		# this row has >= hint boats
		var count := 0
		for j in grid.cols():
			var c := grid.get_cell(i, j)
			if c.has_boat():
				hint -= 1
			elif c.boat_possible() and SolverModel._maybe_extra_boat_col(grid, j):
				count += 1
		if hint > 0 and count == hint:
			var any := false
			for j in grid.cols():
				var c := grid.get_cell(i, j)
				if !c.has_boat() and c.boat_possible() and SolverModel._maybe_extra_boat_col(grid, j):
					if c.put_boat(false, true):
						any = true
			return any
		return false

static func _maybe_extra_boat_on_row(grid: GridImpl, i: int) -> bool:
	var hint := SolverModel._row_hint(grid, i).boat_count
	return hint == -1 or grid.count_boat_row(i) < hint

# Aquariums that CAN and DO NOT have boats. The boat position might not be clear.
# Returns an array of (l, r), meaning ONE boat is possible on grid[l][j]..grid[r][j]
# If l != r means the boat position is not clear, as it may be placed in multiple places
# in the aquarium.
# This is best effort. Two separate aquariums might be unknowingly connected and the
# total possible boats might be smaller.
static func _list_possible_boats_on_col(grid: GridImpl, j: int) -> Array[Vector2i]:
	var i := grid.rows() - 1
	var ans: Array[Vector2i] = []
	while i >= 0:
		var c := grid.get_cell(i, j)
		if c.cell_type() != E.CellType.Single:
			i -= 1
			continue
		var boat_possible := c.boat_possible()
		var had_boat := c.has_boat()
		if not boat_possible:
			i -= 1
			continue
		var r := i
		var l := i
		var stop_moving := c.nowater_full()
		# Cross-eliminate tiles that already have satisfied row hints
		var any_possible := not had_boat and _maybe_extra_boat_on_row(grid, i)
		i -= 1
		# Skip rest of this aquarium. Best effort, they might still be connected through the side.
		while i >= 0 and grid.get_cell(i, j).cell_type() == E.CellType.Single and !grid.get_cell(i, j).wall_at(E.Walls.Bottom):
			c = grid.get_cell(i, j)
			assert(had_boat or stop_moving or not c.nothing_full() or c.boat_possible())
			# Stop moving l when we see nowater, but leave the first nowater as a boat might be there
			if not stop_moving and c.nothing_full():
				l = i
			if not stop_moving and c.nowater_full():
				l = i
				stop_moving = true
			if l == i:
				any_possible = any_possible or (not had_boat and _maybe_extra_boat_on_row(grid, i))
			i -= 1
		if any_possible:
			ans.append(Vector2i(l, r))
	return ans

static func _put_boat_on_col(grid: GridImpl, lr: Vector2i, j: int) -> bool:
	var any := false
	var possible_i := -1
	for i in range(lr.x, lr.y + 1):
		if possible_i != -2 and _maybe_extra_boat_on_row(grid, i):
			if possible_i == -1:
				possible_i = i
			else:
				possible_i = -2
	if possible_i >= 0:
		if grid.get_cell(possible_i, j).put_boat(false, true):
			any = true
	else:
		# Put nowater on top and water on bottom
		if grid.get_cell(lr.x, j).nothing_full():
			if grid.get_cell(lr.x, j).put_nowater(E.Corner.TopLeft, false, true):
				any = true
		if grid._pure_cell(lr.y + 1, j)._content_top() != Content.Water:
			var c := grid.get_cell(lr.y + 1, j)
			if c.put_water(E.diag_to_corner(c.cell_type(), E.Side.Top), false):
				any = true
	return any

class BoatColStrategy extends ColumnStrategy:
	func description() -> String:
		return "If hint is all possible aquariums, put boats in the ones where it's clear"
	func _apply(j: int) -> bool:
		var full_hint := SolverModel._col_hint(grid, j)
		var hint := full_hint.boat_count
		if hint == -1:
			# This case should be handled by infer hint logic
			assert(full_hint.boat_count_type != E.HintType.Together)
			if full_hint.boat_count_type == E.HintType.Separated:
				hint = 2
		var boats_left_min := hint - grid.count_boat_col(j)
		if boats_left_min <= 0:
			return false
		var possible_boats := SolverModel._list_possible_boats_on_col(grid, j)
		if possible_boats.size() == boats_left_min:
			# We can put boats if the places they should go are clear
			var any := false
			for lr in possible_boats:
				if SolverModel._put_boat_on_col(grid, lr, j):
					any = true
			return any
		return false

class Section:
	var start2: int
	var end2: int
	# Either looking at rows, or this is a single cell or half-cell
	var single: bool
	func _init(b2: int) -> void:
		start2 = b2
		end2 = b2
		single = true

class RowColStrategy extends Strategy:
	func _cell(_a: int, _b: int) -> GridImpl.CellWithLoc:
		return GridModel.must_be_implemented()
	func _left() -> E.Side:
		return GridModel.must_be_implemented()
	func _right() -> E.Side:
		return GridModel.must_be_implemented()
	func _a_len() -> int:
		return GridModel.must_be_implemented()
	func _b_len() -> int:
		return GridModel.must_be_implemented()
	func _a_hint(_a: int) -> GridModel.LineHint:
		return GridModel.must_be_implemented()
	func _count_water_a(_a: int) -> float:
		return GridModel.must_be_implemented()
	func _content(a: int, b2: int) -> Content:
		var c := _cell(a, b2 / 2).pure()
		return c._content_side(_right()) if bool(b2 & 1) else c._content_side(_left())
	func _corner(a: int, b2: int) -> E.Corner:
		return E.diag_to_corner(_cell(a, b2 / 2).cell_type(), _right() if bool(b2 & 1) else _left())
	func _wall_right(a: int, b2: int) -> bool:
		if b2 < 0:
			return true
		var c := _cell(a, b2 / 2)
		return c.wall_at(_right() as E.Walls) if bool(b2 & 1) else (c.cell_type() != E.CellType.Single)
	# Adding water to this cell will flood water to how many half-cells?
	func _will_flood_how_many(a: int, b2: int, invert_flood := false) -> int:
		if _content(a, b2) != Content.Nothing:
			return 0
		var b2_min := b2
		var b2_max := b2
		# Always floods right or down
		if _left() == E.Side.Left or not invert_flood:
			while not _wall_right(a, b2_max) and _content(a, b2_max + 1) == Content.Nothing:
				b2_max += 1
		else:
			if not bool(b2_max & 1) and not _wall_right(a, b2_max):
				b2_max += 1
		# Only floods left, not up
		if _left() == E.Side.Left or invert_flood:
			while b2_min > 0 and not _wall_right(a, b2_min - 1) and _content(a, b2_min - 1) == Content.Nothing:
				b2_min -= 1
		# But up it still "floods" the same cell if it doesn't have a diagonal
		else:
			if bool(b2_min & 1) and not _wall_right(a, b2_min - 1):
				b2_min -= 1
		return b2_max - b2_min + 1

	func _empty_sections(a: int) -> Array[Section]:
		var ans: Array[Section] = []
		for b2 in range(2 * _b_len()):
			if _content(a, b2) == Content.Nothing:
				if ans.is_empty() or _wall_right(a, b2 - 1) or ans.back().end2 < b2 - 1:
					ans.append(Section.new(b2))
				else:
					ans.back().end2 = b2
					if _left() != E.Side.Left and not bool(b2 & 1):
						ans.back().single = false
		return ans

# Logic for both row and column is the same, so let's make it generic
# Instead of (rows, cols) (i, j), let's use (a_len, b_len) (a, b)
class TogetherStrategy extends RowColStrategy:
	var basic: bool

	func _init(grid_: GridImpl, basic_: bool) -> void:
		super(grid_)
		basic = basic_

	func description() -> String:
		if basic:
			return """
			- If there's two waters in the {line}, they must be connected
			- If there's water in the {line}, far away cells can't have water
			"""
		else:
			return """
			- If there's water and its close to the border, we might need to expand it to the other side
			- If there's the space between two obstacles is less than N, then it can't have any water
			"""

	func _basic_waters_and_nowaters(a: int) -> bool:
		# Very simplistic logic, jut put water in the middle if the hint is big
		# The function below also covers this, but we're using this for "basic mode"
		var h := _a_hint(a).water_count
		var b_len := _b_len()
		var any := false
		if h * 2 > b_len:
			for b2 in range(b_len - (int(2 * h) - b_len), b_len + (int(2 * h) - b_len)):
				if _content(a, b2) != Content.Water:
					_cell(a, b2 / 2).put_water(_corner(a, b2), false)
					any = true
		return any

	# If there's no water and a single empty aquarium, add water to it from the bottom
	# Assumes there's no water and the hint is {?}
	func _maybe_add_single_water(a: int) -> bool:
		if not basic:
			return false
		var last_empty_b2 := -1
		for b2 in 2 * _b_len():
			if _content(a, b2) == Content.Nothing or _content(a, b2) == Content.NoBoat:
				if last_empty_b2 != -1 and ((_content(a, b2 - 1) != Content.Nothing and _content(a, b2 - 1) != Content.NoBoat) or _wall_right(a, b2 - 1)):
					# Not a single aquarium
					return false
				last_empty_b2 = b2
		# Should be true if we haven't fucked up
		if last_empty_b2 != -1:
			# Add water to the single aquarium as {?} implies non-zero water
			_cell(a, last_empty_b2 / 2).put_water(_corner(a, last_empty_b2), false)
			return true
		return false

	# Like the subset sum strategy on rows, but since it's required to be together, we actually
	# need only to use the two pointers technique to check all possible solutions
	# Assumes there's no water in this row/column
	func _add_necessary_waters_and_nowaters(a: int) -> bool:
		var hint := int(2 * _a_hint(a).water_count)
		if hint <= 0:
			return _maybe_add_single_water(a)
		if basic:
			return _basic_waters_and_nowaters(a)
		var any := false
		var r2 := -1
		var l2 := 0
		var max_solution_right := -1
		var min_solution_right := -1
		var max_solution_left := -1
		while l2 < 2 * _b_len():
			if _content(a, l2) != Content.Nothing:
				l2 += 1
				continue
			if r2 < l2:
				r2 = l2 - 1
			while r2 < 2 * _b_len() - 1 and _content(a, r2 + 1) == Content.Nothing and r2 - l2 + 1 < hint:
				r2 += 1
				while r2 < l2 or (not _wall_right(a, r2) and _content(a, r2 + 1) == Content.Nothing):
					r2 += 1
			if r2 - l2 + 1 == hint:
				max_solution_right = r2
				max_solution_left = l2
				if min_solution_right == -1:
					min_solution_right = r2
			# This cell is not in ANY solution
			if max_solution_right < l2:
				any = true
				_cell(a, l2 / 2).put_nowater(_corner(a, l2), false, true)
			if _left() == E.Left:
				while not _wall_right(a, l2):
					l2 += 1
			else:
				if not bool(l2 & 1) and not _wall_right(a, l2):
					l2 += 1
			l2 += 1
		# Every cell between max_solution_left and min_solution_right are in EVERY solution
		for b2 in range(max_solution_left, min_solution_right + 1, 1):
			if _content(a, b2) == Content.Nothing:
				_cell(a, b2 / 2).put_water(_corner(a, b2), false)
				any = true
		return any

	func _apply(a: int) -> bool:
		var a_hint := _a_hint(a)
		if a_hint.water_count_type != E.HintType.Together:
			return false
		var leftmost := 2 * _b_len()
		var rightmost := -1
		for b2 in 2 * _b_len():
			if _content(a, b2) == Content.Water:
				leftmost = min(leftmost, b2)
				rightmost = b2
		if rightmost == -1:
			return _add_necessary_waters_and_nowaters(a)
		var any := false
		if basic:
			# Merge all waters together
			for b2 in range(leftmost + 1, rightmost):
				var content := _content(a, b2)
				if content != Content.Water:
					any = true
					_cell(a, b2 / 2).put_water(_corner(a, b2), false)
			if any:
				return true
		# Mark far away cells as empty
		var min_b2 := leftmost
		while min_b2 > 0 and _content(a, min_b2 - 1) == Content.Nothing:
			min_b2 -= 1
		var max_b2 := rightmost
		while max_b2 < 2 * _b_len() - 1 and _content(a, max_b2 + 1) == Content.Nothing:
			max_b2 += 1

		var hint := a_hint.water_count
		var water_left2 := int(2 * (hint - _count_water_a(a)))
		if water_left2 < 0:
			# Invalid solution
			if hint >= 0:
				return false
		if basic:
			var no_b2 := []
			if water_left2 >= 0:
				no_b2.append_array(range(rightmost + water_left2 + 1, max_b2 + 1)) # Far to the right
				no_b2.append_array(range(leftmost - water_left2 - 1, min_b2 - 1, -1)) # Far to the left
			no_b2.append_array(range(0, min_b2)) # Before block/nowater
			no_b2.append_array(range(max_b2 + 1, 2 * _b_len())) # After block/nowater
			for b2 in no_b2:
				if _content(a, b2) == Content.Nothing:
					any = true
					_cell(a, b2 / 2).put_nowater(_corner(a, b2), false, true)
		else:
			if water_left2 < 0:
				return any
			# Mark nearby cells as full if close to the "border"
			var yes_b2 := []
			if leftmost - min_b2 < water_left2:
				yes_b2.append_array(range(rightmost + 1, min(rightmost + 1 + water_left2 - (leftmost - min_b2), 2 * _b_len())))
			if max_b2 - rightmost < water_left2:
				yes_b2.append_array(range(max(0, leftmost - (water_left2 - (max_b2 - rightmost))), leftmost))
			for b2 in yes_b2:
				if _content(a, b2) != Content.Water:
					any = true
					_cell(a, b2 / 2).put_water(_corner(a, b2), false)
		return any

	func apply_any() -> bool:
		var any := false
		for a in _a_len():
			if _apply(a):
				any = true
		return any


class TogetherRowStrategy extends TogetherStrategy:
	func description() -> String:
		return super.description().format({line = "row"})
	func _cell(a: int, b: int) -> GridImpl.CellWithLoc:
		return grid.get_cell(a, b) as GridImpl.CellWithLoc
	func _left() -> E.Side:
		return E.Side.Left
	func _right() -> E.Side:
		return E.Side.Right
	func _a_len() -> int:
		return grid.rows()
	func _b_len() -> int:
		return grid.cols()
	func _a_hint(a: int) -> GridModel.LineHint:
		return SolverModel._row_hint(grid, a)
	func _count_water_a(a: int) -> float:
		return grid.count_water_row(a)

class TogetherColStrategy extends TogetherStrategy:
	func description() -> String:
		return super.description().format({line = "column"})
	func _cell(a: int, b: int) -> GridImpl.CellWithLoc:
		return grid.get_cell(b, a) as GridImpl.CellWithLoc
	func _left() -> E.Side:
		return E.Side.Top
	func _right() -> E.Side:
		return E.Side.Bottom
	func _a_len() -> int:
		return grid.cols()
	func _b_len() -> int:
		return grid.rows()
	func _a_hint(a: int) -> GridModel.LineHint:
		return SolverModel._col_hint(grid, a)
	func _count_water_a(a: int) -> float:
		return grid.count_water_col(a)

enum TogetherStatus { None, AlwaysTogether, MaybeSeparated }
enum { BEFORE, DURING, AFTER, SEPARATED }
class SeparateStrategy extends RowColStrategy:
	var basic: bool
	
	func _init(grid_: GridImpl, basic_: bool) -> void:
		super(grid_)
		basic = basic_
	
	func description() -> String:
		if basic:
			return """
			Add NoWater to cells that would flood exactly the -N- cells
			"""
		else:
			return """
			If adding water to a single cell would cause the waters to be together and
			fullfill the hint, we can't add water to that cell.
			"""
	func _nothing(a: int, b2: int) -> bool:
		var c := _content(a, b2)
		return c == Content.Nothing or c == Content.NoBoat

	func _water_or_nothing(a: int, b2: int) -> bool:
		return _content(a, b2) == Content.Water or _nothing(a, b2)

	func _skip_right(a: int, b2: int, more_than_single: bool) -> int:
		if not bool(b2 & 1) and not _wall_right(a, b2):
			b2 += 1
		while more_than_single and not _wall_right(a, b2):
			b2 += 1
		return b2 + 1
	
	func _skip_left(a: int, b2: int, more_than_single: bool) -> int:
		if bool(b2 & 1) and not _wall_right(a, b2 - 1):
			b2 -= 1
		while more_than_single and b2 > 0 and not _wall_right(a, b2 - 1):
			b2 -= 1
		return b2 - 1

	func _will_be_together_right(a: int, b2: int) -> TogetherStatus:
		while b2 < 2 * _b_len() and not _water_or_nothing(a, b2):
			b2 += 1
		if b2 == 2 * _b_len():
			return TogetherStatus.None
		if _content(a, b2) != Content.Water:
			b2 = _skip_right(a, b2, true)
		if b2 == 2 * _b_len():
			return TogetherStatus.AlwaysTogether
		while b2 < 2 * _b_len() and _content(a, b2) == Content.Water:
			b2 += 1
		if b2 == 2 * _b_len():
			return TogetherStatus.AlwaysTogether
		b2 = _skip_right(a, b2, _left() == E.Left)
		while b2 < 2 * _b_len():
			if _water_or_nothing(a, b2):
				return TogetherStatus.MaybeSeparated
			b2 += 1
		return TogetherStatus.AlwaysTogether

	func _will_be_together_left(a: int, b2: int) -> TogetherStatus:
		while b2 >= 0 and not _water_or_nothing(a, b2):
			b2 -= 1
		if b2 < 0:
			return TogetherStatus.None
		if _content(a, b2) != Content.Water:
			b2 = _skip_left(a, b2, _left() == E.Left)
		if b2 < 0:
			return TogetherStatus.AlwaysTogether
		while b2 >= 0 and _content(a, b2) == Content.Water:
			b2 -= 1
		if b2 < 0:
			return TogetherStatus.AlwaysTogether
		b2 = _skip_left(a, b2, true)
		while b2 >= 0:
			if _water_or_nothing(a, b2):
				return TogetherStatus.MaybeSeparated
			b2 -= 1
		return TogetherStatus.AlwaysTogether

	func try_sections_strat(a: int) -> bool:
		var sections := _empty_sections(a)
		if sections.size() > 3 or sections.is_empty():
			return false
		for section in sections:
			# Try to put water on everything, if it's AlwaysTogether it means we need a NoWater here
			if _nothing(a, section.start2) and _will_be_together_right(a, section.end2) == TogetherStatus.AlwaysTogether and \
			   _will_be_together_left(a, section.start2) == TogetherStatus.AlwaysTogether:
				return _cell(a, section.start2 / 2).put_nowater(_corner(a, section.start2), false, true)
			# Try to put NoWater here, if it's AlwaysTogether it means we need Water here
			if _nothing(a, section.end2):
				match [_will_be_together_right(a, section.end2 + 1), _will_be_together_left(a, section.start2 - 1)]:
					[TogetherStatus.AlwaysTogether, TogetherStatus.None], [TogetherStatus.None, TogetherStatus.AlwaysTogether]:
						return _cell(a, section.end2 / 2).put_water(_corner(a, section.end2), false)
		return false

	func _apply(a: int) -> bool:
		var hint := _a_hint(a)
		if hint.water_count_type != E.HintType.Separated:
			return false
		if not basic and try_sections_strat(a):
			return true
		if hint.water_count_type != E.HintType.Separated or hint.water_count == -1.:
			return false
		var water_left2 := int(2 * (hint.water_count - _count_water_a(a)))
		if water_left2 < 0:
			return false
		var any := false
		if not basic:
			# Maybe we need to put water in corners to avoid having contiguous water
			for b2 in 2 * _b_len():
				if _nothing(a, b2):
					var b2_r := _skip_right(a, b2, _left() == E.Side.Left)
					var state := BEFORE
					var left2 := int(2 * hint.water_count)
					for c2 in range(b2_r, 2 * _b_len()):
						if _water_or_nothing(a, c2):
							if state == BEFORE:
								state = DURING
							elif state == AFTER:
								state = SEPARATED
							left2 -= 1
						elif state == DURING:
							state = AFTER
					if state != SEPARATED and left2 == 0:
						any = true
						_cell(a, b2 / 2).put_water(_corner(a, b2), false)
					break
				elif _content(a, b2) == Content.Water:
					break
			for b2 in range(2 * _b_len() - 1, -1, -1):
				if _nothing(a, b2):
					var b2_l := _skip_left(a, b2, true)
					var state := BEFORE
					var left2 := int(2 * hint.water_count)
					for c2 in range(b2_l, -1, -1):
						if _water_or_nothing(a, c2):
							if state == BEFORE:
								state = DURING
							elif state == AFTER:
								state = SEPARATED
							left2 -= 1
						elif state == DURING:
							state = AFTER
					if state != SEPARATED and left2 == 0:
						any = true
						_cell(a, b2 / 2).put_water(_corner(a, b2), false)
					break
				elif _content(a, b2) == Content.Water:
					break
		var leftmost := 2 * _b_len()
		var rightmost := -1
		for b2 in 2 * _b_len():
			if _content(a, b2) == Content.Water:
				leftmost = min(leftmost, b2)
				rightmost = b2
		if rightmost == -1:
			# We can mark connected components of size exactly the hint as nowater
			# because otherwise it would be together. This will work differently in rows and cols.
			for b2 in 2 * _b_len():
				if _content(a, b2) == Content.Nothing:
					# Hole is already discontinuous
					if rightmost != -1 and rightmost != b2 - 1:
						leftmost = -1
					leftmost = min(leftmost, b2)
					rightmost = b2
					if basic and _will_flood_how_many(a, b2) == water_left2:
						_cell(a, b2 / 2).put_nowater(_corner(a, b2), false, true)
						any = true
			return any
		if not basic:
			return any
		var not_water_middle := (rightmost - leftmost + 1) - int(2 * _count_water_a(a))
		for b2 in range(leftmost + 1, rightmost):
			var c := _content(a, b2)
			if c != Content.Water:
				if not_water_middle == water_left2 and (c == Content.Nothing or c == Content.NoBoat) and _will_flood_how_many(a, b2) == water_left2:
					_cell(a, b2 / 2).put_nowater(_corner(a, b2), false, true)
					return true
				return false
		if _left() == E.Side.Top:
			# Walk up until we find a cell if we put water it will flood exactly water_left2
			var b2 := leftmost - 1
			while b2 >= 0 and _content(a, b2) == Content.Nothing:
				if bool(b2 & 1) and _cell(a, (b2 / 2)).cell_type() == E.CellType.Single:
					b2 -= 1
				if leftmost - b2 == water_left2:
					_cell(a, b2 / 2).put_nowater(_corner(a, b2), false, true)
					any = true
					break
				if leftmost - b2 > water_left2 or b2 == 0 or _wall_right(a, b2 - 1):
					break
				else:
					b2 -= 1
		else:
			if leftmost > 0 and (_content(a, leftmost - 1) == Content.Nothing or _content(a, leftmost - 1) == Content.NoBoat) and _will_flood_how_many(a, leftmost - 1) == water_left2:
				_cell(a, (leftmost - 1) / 2).put_nowater(_corner(a, leftmost - 1), false, true)
				any = true
		if rightmost < _b_len() * 2 - 1 and _content(a, rightmost + 1) == Content.Nothing and _will_flood_how_many(a, rightmost + 1) == water_left2:
			_cell(a, (rightmost + 1) / 2).put_nowater(_corner(a, rightmost + 1), false, true)
			any = true
		return any

	func apply_any() -> bool:
		var any := false
		for a in _a_len():
			if _apply(a):
				any = true
		return any

class SeparateRowStrategy extends SeparateStrategy:
	func _cell(a: int, b: int) -> GridImpl.CellWithLoc:
		return grid.get_cell(a, b) as GridImpl.CellWithLoc
	func _left() -> E.Side:
		return E.Side.Left
	func _right() -> E.Side:
		return E.Side.Right
	func _a_len() -> int:
		return grid.rows()
	func _b_len() -> int:
		return grid.cols()
	func _a_hint(a: int) -> GridModel.LineHint:
		return SolverModel._row_hint(grid, a)
	func _count_water_a(a: int) -> float:
		return grid.count_water_row(a)

class SeparateColStrategy extends SeparateStrategy:
	func _cell(a: int, b: int) -> GridImpl.CellWithLoc:
		return grid.get_cell(b, a) as GridImpl.CellWithLoc
	func _left() -> E.Side:
		return E.Side.Top
	func _right() -> E.Side:
		return E.Side.Bottom
	func _a_len() -> int:
		return grid.cols()
	func _b_len() -> int:
		return grid.rows()
	func _a_hint(a: int) -> GridModel.LineHint:
		return SolverModel._col_hint(grid, a)
	func _count_water_a(a: int) -> float:
		return grid.count_water_col(a)

class AllWatersEasyStrategy extends Strategy:
	func description() -> String:
		return """
		- If remaining waters is 0, mark everything with nowater.
		- If the remaining empty spaces equal the total waters, fill them all."""
	func apply_any() -> bool:
		if grid.grid_hints().total_water == -1.0:
			return false
		var water_left := grid.grid_hints().total_water - grid.count_waters()
		if water_left < 0:
			return false
		var any := false
		if water_left == 0:
			for i in grid.rows():
				for j in grid.cols():
					var c := grid.get_cell(i, j)
					for corner in c.corners():
						if c.nothing_at(corner):
							if c.put_nowater(corner, false, true):
								any = true
			return any
		var count_nothing := 0.0
		for i in grid.rows():
			for j in grid.cols():
				count_nothing += grid._pure_cell(i, j).nothing_count()
		if water_left == count_nothing:
			for i in grid.rows():
				for j in grid.cols():
					var c := grid.get_cell(i, j)
					for corner in c.corners():
						if c.nothing_at(corner):
							if c.put_water(corner, false):
								any = true
		return any

class AllWatersMediumStrategy extends Strategy:
	func description() -> String:
		return """
		- If flooding water on a tile would create too many waters, mark it with nowater.
		- Same for flooding nowater and adding water."""
	func apply_any() -> bool:
		if grid.grid_hints().total_water == -1.0:
			return false
		var water_left := grid.grid_hints().total_water - grid.count_waters()
		if water_left <= 0:
			return false
		var any := false
		for i in grid.rows():
			for j in grid.cols():
				var c := grid.get_cell(i, j)
				for corner in c.corners():
					if not c.nothing_at(corner):
						continue
					# This if is just an optimisation since we only need to test this once on this line x aquarium
					if c.wall_at(E.Walls.Left) if E.corner_is_left(corner) else c.cell_type() != E.CellType.Single:
						if c.water_would_flood_how_many(corner) > water_left:
							if c.put_nowater(corner, false, true):
								any = true
		water_left = grid.grid_hints().total_water - grid.count_waters()
		var count_nothing := 0.0
		for i in grid.rows():
			for j in grid.cols():
				count_nothing += grid._pure_cell(i, j).nothing_count()
		if water_left > count_nothing:
			return any
		for i in grid.rows():
			for j in grid.cols():
				var c := grid.get_cell(i, j)
				for corner in c.corners():
					if not c.nothing_at(corner):
						continue
					# This if is just an optimisation since we only need to test this once on this line x aquarium
					if c.wall_at(E.Walls.Left) if E.corner_is_left(corner) else c.cell_type() != E.CellType.Single:
						if water_left > count_nothing - c.nowater_would_flood_how_many(corner):
							if c.put_water(corner, false):
								any = true
		return any

class AllBoatsStrategy extends Strategy:
	func description() -> String:
		return "If all boat possible locations is the remaining hint, fill everything with boats."
	func apply_any() -> bool:
		var boats_left := grid.grid_hints().total_boats - grid.count_boats()
		if boats_left <= 0:
			return false
		var possible_boats: Array[Array] = []
		var total_possible := 0
		for j in grid.cols():
			if not SolverModel._maybe_extra_boat_col(grid, j):
				possible_boats.append([])
				continue
			var p := SolverModel._list_possible_boats_on_col(grid, j)
			total_possible += p.size()
			possible_boats.append(p)
		var any := false
		if total_possible == boats_left:
			for j in grid.cols():
				for lr in possible_boats[j]:
					if SolverModel._put_boat_on_col(grid, lr, j):
						any = true
		return any

static func _put_water(grid: GridImpl, pos: GridModel.WaterPosition) -> void:
	var corner := (pos.loc as E.Corner) if pos.loc != E.Single else E.Corner.TopLeft
	var c := grid.get_cell(pos.i, pos.j)
	if not c.water_at(corner):
		var added := grid.get_cell(pos.i, pos.j).put_water(corner, false)
		assert(added > 0, "_put_water call but didn't succeed to put water")

static func _put_nowater(grid: GridImpl, pos: GridModel.WaterPosition) -> void:
	var corner := (pos.loc as E.Corner) if pos.loc != E.Single else E.Corner.TopLeft
	var c := grid.get_cell(pos.i, pos.j)
	if c.nothing_at(corner) or c.noboat_at(corner):
		c.put_nowater(corner, false, true)

class AquariumsStrategy extends Strategy:
	var basic: bool
	func _init(grid_: GridImpl, basic_: bool) -> void:
		super(grid_)
		basic = basic_
	func description() -> String:
		if basic:
			return "- If for a given aquarium there can't be aquariums with this much water, add more."
		return """
		- If for a given aquarium, it can't be filled up, add nowater.
		- If there's exactly one way to fill an aquarium to a certain value that's required, do it.
		- Mostly ignores aquariums that have "pools", unless they are already filled.
		"""
	func _maybe_add_last_aquarium(hints: Dictionary, all_aqs: Array[GridImpl.AquariumInfo]) -> void:
		var water_left := grid.grid_hints().total_water - grid.count_waters()
		if not hints.has(0.0) or water_left <= 0 or hints.has(water_left):
			return
		var non_fixed_0s := 0
		for aq in all_aqs:
			if aq.total_water == 0 and not aq.fixed_water():
				non_fixed_0s += 1
			if not aq.fixed_water() and aq.total_water > 0:
				return
		# Now we know only 0s are non-fixed
		if non_fixed_0s == hints[0.0] + 1:
			# We can only fill one more aquarium so it must have this value
			hints[water_left] = 1
	func _infer_if_rest_is_0(hints: Dictionary, all_aqs: Array[GridImpl.AquariumInfo]) -> void:
		if grid.grid_hints().total_water == -1:
			return
		var fixed_aqs := {}
		var water_in_hints_and_fixed_aqs := 0.0
		var biggest_aq := 0.0
		for h in hints:
			water_in_hints_and_fixed_aqs += h * hints[h]
		for aq in all_aqs:
			biggest_aq = maxf(biggest_aq, aq.total_empty + aq.total_water)
			if aq.fixed_water() and not hints.has(aq.total_water):
				fixed_aqs[aq.total_water] = fixed_aqs.get(aq.total_water, 0) + 1
				water_in_hints_and_fixed_aqs += aq.total_water
		if grid.grid_hints().total_water != water_in_hints_and_fixed_aqs:
			return
		var filled_aqs_count := 0
		while biggest_aq > 0:
			if not hints.has(biggest_aq):
				hints[biggest_aq] = fixed_aqs.get(biggest_aq, 0)
			filled_aqs_count += hints[biggest_aq]
			biggest_aq -= 0.5
		if all_aqs.size() >= filled_aqs_count:
			hints[0.0] = all_aqs.size() - filled_aqs_count
	func apply_any() -> bool:
		var hint := grid.grid_hints().expected_aquariums.duplicate()
		if hint.is_empty():
			return false
		var all_aqs: Array[GridImpl.AquariumInfo] = []
		var dfs := GridImpl.CrawlAquarium.new(grid)
		# This will change, let's store it
		var last_seen := grid.last_seen
		# Bottom up for correctness
		for i in range(grid.rows() - 1, -1, -1):
			for j in grid.cols():
				for corner in grid.get_cell(i, j).corners():
					var c := grid._pure_cell(i, j)
					if c.last_seen(corner) < last_seen and not c.block_at(corner):
						dfs.reset()
						dfs.flood(i, j, corner)
						dfs.reset_for_pool_check()
						dfs.flood(i, j, corner)
						all_aqs.append(dfs.info)
		_infer_if_rest_is_0(hint, all_aqs)
		var var_aqs: Array[GridImpl.AquariumInfo] = []
		var any_pools := false
		var ways_to_reach := {}
		for aq in all_aqs:
			if aq.fixed_water():
				if hint.has(aq.total_water):
					hint[aq.total_water] -= 1
					# Invalid
					if hint[aq.total_water] < 0:
						return false
			else:
				any_pools = any_pools or aq.has_pool
				if not aq.has_pool:
					var_aqs.append(aq)
				if any_pools:
					continue
				# Since it doesn't have pools, there's a unique way to fill it out
				var reaches := aq.total_water
				ways_to_reach[reaches] = ways_to_reach.get(reaches, 0) + 1
				for val in aq.empty_at_height:
					if val == 0:
						continue
					reaches += val
					ways_to_reach[reaches] = ways_to_reach.get(reaches, 0) + 1
		_maybe_add_last_aquarium(hint, all_aqs)
		var any := false
		if basic:
			for aq in var_aqs:
				# It needs more water while the low values are 0 on the hints
				var reaches := aq.total_water
				for i in aq.empty_at_height.size():
					if aq.empty_at_height[i] <= 0:
						continue
					if hint.get(reaches, -1) == 0:
						for pos in aq.cells_at_height[i]:
							SolverModel._put_water(grid, pos)
						reaches += aq.empty_at_height[i]
						any = true
					else:
						break
		if any or basic:
			return any
		# If there are exactly the required number of ways to reach the given hint, do them all
		# This require any_pools = 0 otherwise we can't properly calculate the ways to reach a hint
		for sz in hint:
			if hint[sz] == 0 or hint[sz] != ways_to_reach.get(sz, 0) or any_pools:
				continue
			for aq in var_aqs:
				var reaches := aq.total_water
				for i in aq.empty_at_height.size():
					if aq.empty_at_height[i] <= 0:
						continue
					elif reaches == sz:
						for pos in aq.cells_at_height[i]:
							SolverModel._put_nowater(grid, pos)
						any = true
					else:
						reaches += aq.empty_at_height[i]
						if reaches == sz:
							for pos in aq.cells_at_height[i]:
								SolverModel._put_water(grid, pos)
							any = true
		if any:
			return true
		# Put airs on the top while the high values of reaches are 0 in the hints
		for aq in var_aqs:
			var reaches := aq.total_water + aq.total_empty
			for i in range(aq.empty_at_height.size() - 1, -1, -1):
				if aq.empty_at_height[i] <= 0:
					continue
				if hint.get(reaches, -1) == 0:
					for pos in aq.cells_at_height[i]:
						SolverModel._put_nowater(grid, pos)
					reaches -= aq.empty_at_height[i]
					any = true
				else:
					break
		return any

# We need these func's because of a Godot internal issue on release builds
# https://github.com/godotengine/godot/issues/80526
static var STRATEGY_LIST := {
	BasicRow = func(grid): return BasicRowStrategy.new(grid),
	BasicCol = func(grid): return BasicColStrategy.new(grid),
	FullPropagateNoWater = func(grid): return FullPropagateNoWater.new(grid),
	BoatRow = func(grid): return BoatRowStrategy.new(grid),
	BoatCol = func(grid): return BoatColStrategy.new(grid),
	MediumRow = func(grid): return MediumRowStrategy.new(grid),
	MediumCol = func(grid): return MediumColStrategy.new(grid),
	AdvancedRow = func(grid): return AdvancedRowStrategy.new(grid),
	AdvancedCol = func(grid): return AdvancedColStrategy.new(grid),
	TogetherRowBasic = func(grid): return TogetherRowStrategy.new(grid, true),
	TogetherRowAdvanced = func(grid): return TogetherRowStrategy.new(grid, false),
	TogetherColBasic = func(grid): return TogetherColStrategy.new(grid, true),
	TogetherColAdvanced = func(grid): return TogetherColStrategy.new(grid, false),
	SeparateRowBasic = func(grid): return SeparateRowStrategy.new(grid, true),
	SeparateRowAdvanced = func(grid): return SeparateRowStrategy.new(grid, false),
	SeparateColBasic = func(grid): return SeparateColStrategy.new(grid, true),
	SeparateColAdvanced = func(grid): return SeparateColStrategy.new(grid, false),
	AllWatersEasy = func(grid): return AllWatersEasyStrategy.new(grid),
	AllWatersMedium = func(grid): return AllWatersMediumStrategy.new(grid),
	AllBoats = func(grid): return AllBoatsStrategy.new(grid),
	AquariumsBasic = func(grid): return AquariumsStrategy.new(grid, true),
	AquariumsAdvanced = func(grid): return AquariumsStrategy.new(grid, false),
}

# Get a place in the solution that must have nowater and put a block on it
# This makes strategies easier to apply
func _put_block_on_nowater(grid: GridImpl) -> bool:
	for i in grid.rows():
		for j in grid.cols():
			var c := grid.get_cell(i, j)
			for corner in c.corners():
				var sol := grid._content_sol(i, j, corner)
				if c.nothing_at(corner) and GridImpl.empty_ish(sol):
					return c.put_block(corner, false)
	return false

# May add blocks to the grid
func can_solve_with_strategies(grid_: GridModel, strategies_names: Array, forced_strategies_or: Array) -> bool:
	var grid: GridImpl = grid_ as GridImpl
	assert(not grid.editor_mode())
	grid.force_editor_mode()
	assert(not grid.auto_update_hints())
	for s in forced_strategies_or:
		if strategies_names.find(s) == -1:
			strategies_names.append(s)
	while true:
		apply_strategies(grid, strategies_names, false)
		if grid.check_complete():
			match grid.all_hints_status():
				E.HintStatus.Wrong:
					push_error("Fucked up somehow")
					return false
				E.HintStatus.Satisfied:
					break
		if not _put_block_on_nowater(grid):
			return false
	grid.clear_content()
	apply_strategies(grid, strategies_names)
	# Sometimes adding blocks make some strategies stop working
	if not grid.are_hints_satisfied(true):
		return false
	if forced_strategies_or.is_empty():
		return true
	grid.clear_content()
	apply_strategies(grid, strategies_names.filter(func(s2): return forced_strategies_or.find(s2) == -1), false)
	if grid.are_hints_satisfied():
		return false
	return true

# Tries to solve the puzzle as much as possible. Returns whether it did anything.
func apply_strategies(grid: GridModel, strategies_names: Array, flush_undo := true) -> bool:
	# We'll merge all changes in the same undo here
	if flush_undo:
		grid.push_empty_undo()
	# Player may have left incomplete s
	grid.flood_nowater(false)
	var strategies := {}
	for name in strategies_names:
		strategies[name] = STRATEGY_LIST[name].call(grid)
	for t in 50:
		var any := false
		for name in strategies_names:
			if strategies[name].apply_any():
				if t > 35:
					grid.copy_to_clipboard()
					print("[%d] Applied %s" % [t, name])
				any = true
				# Earlier strategies are usually simpler, let's try to run them more
				# Also, some strategies depend on others having run
				break
		if not any:
			return t > 0
		assert(t < 40)
	return true

enum SolveResult { SolvedUniqueNoGuess, SolvedUnique, SolvedMultiple, Unsolvable, GaveUp }


func _make_guess(res: SolveResult) -> SolveResult:
	match res:
		SolveResult.SolvedUniqueNoGuess:
			return SolveResult.SolvedUnique
		_:
			return res

const MAX_GUESSES := 2

# Will apply strategies but also try to guess
# If look_for_multiple = false, will not try to look for multiple solutions
func full_solve(grid: GridModel, strategy_list: Array, cancel_sig: Callable, flush_undo := true, guesses_left := MAX_GUESSES, min_boat_place := Vector2i.ZERO, look_for_multiple := true) -> SolveResult:
	assert(grid.editor_mode() and not grid.auto_update_hints())
	if flush_undo:
		grid.push_empty_undo()
	if cancel_sig.call() or guesses_left < 0:
		return SolveResult.GaveUp
	apply_strategies(grid, strategy_list, false)
	var status := grid.all_hints_status()
	if status == E.HintStatus.Wrong:
		#grid.copy_to_clipboard()
		return SolveResult.Unsolvable
	if status == E.HintStatus.Satisfied and grid.check_complete():
		# Since we don't have "s that don't have boats" we need this
		if grid.any_schrodinger_boats():
			return SolveResult.SolvedMultiple
		return SolveResult.SolvedUniqueNoGuess
	for i in grid.rows():
		for j in grid.cols():
			for corner in E.Corner.values():
				var c := grid.get_cell(i, j)
				if c.nothing_at(corner):
					# New undo stack
					c.put_water(corner, true)
					var r1 := full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, min_boat_place, look_for_multiple)
					grid.undo()
					# Unsolvable means there's definitely no water here. Tail recurse.
					if r1 == SolveResult.Unsolvable:
						c.put_nowater(corner, false)
						return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, min_boat_place, look_for_multiple))
					elif not look_for_multiple or r1 == SolveResult.SolvedMultiple or r1 == SolveResult.GaveUp:
						grid.redo()
						return r1
					# Otherwise we need to try to solve with nowater
					c.put_nowater(corner, true, true)
					var r2 := full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, min_boat_place, false)
					# It definitely had water
					if r2 == SolveResult.Unsolvable:
						grid.undo()
						c.put_water(corner, false)
						# TODO: Maybe here we could store the undo stack and reuse it
						# Doesn't really make it much faster
						return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, min_boat_place, look_for_multiple))
					# Could solve both ways, definitely not unique
					# If GaveUp, might be multiple or unique, let's be pessimistic.
					return SolveResult.SolvedMultiple
	# After we guessed all waters and s, let's guess boats if we at least got the waters right
	for i in grid.rows():
		if grid.get_row_hint_status(i, E.HintContent.Water) == E.HintStatus.Wrong:
			return SolveResult.Unsolvable 
	for j in grid.cols():
		if grid.get_col_hint_status(j, E.HintContent.Water) == E.HintStatus.Wrong:
			return SolveResult.Unsolvable
	if grid.all_waters_hint_status() == E.HintStatus.Wrong or grid.aquarium_hints_status() == E.HintStatus.Wrong:
		return SolveResult.Unsolvable
	for i in grid.rows():
		for j in grid.cols():
			var c := grid.get_cell(i, j)
			if Vector2i(i, j) < min_boat_place or !c.boat_possible() or c.has_boat():
				continue
			var b := c.put_boat(true, true)
			assert(b)
			var r1 := full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, Vector2i(i, j + 1), look_for_multiple)
			grid.undo()
			if r1 == SolveResult.Unsolvable:
				return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, Vector2i(i, j + 1), look_for_multiple))
			elif not look_for_multiple or r1 == SolveResult.SolvedMultiple or r1 == SolveResult.GaveUp:
				grid.redo()
				return r1
			var r2 := full_solve(grid, strategy_list, cancel_sig, true, guesses_left - 1, Vector2i(i, j + 1), false)
			grid.undo(false)
			if r2 == SolveResult.Unsolvable:
				b = c.put_boat(false, true)
				assert(b)
				return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, Vector2i(i, j + 1), look_for_multiple))
			else:
				grid.redo(false)
				return SolveResult.SolvedMultiple
	# Can't really guess anything else
	return SolveResult.Unsolvable
