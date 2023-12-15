class_name SolverModel

const Content := GridImpl.Content

class Strategy:
	var grid: GridImpl
	func _init(grid_: GridImpl) -> void:
		grid = grid_
	func apply_any() -> bool:
		return GridModel.must_be_implemented()
	static func description() -> String:
		return "No description"

# Strategy for a single row
class RowStrategy extends Strategy:
	# values is an array of component, that is, all triangles
	# are in the same aquarium. Each of the triangles in the component MUST be
	# flooded all at once with water or air. Each distinct componene IS completely
	# independent.
	func _apply_strategy(_i: int, _values: Array[RowComponent], _water_left: float, _nothing_left: float) -> bool:
		return GridModel.must_be_implemented()
	func _apply(i: int) -> bool:
		if grid.row_hints()[i].water_count < 0:
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
		var water_left := grid.row_hints()[i].water_count - grid.count_water_row(i)
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
	func put_air() -> void:
		first.put_air(corner, false, true)

class RowDfs extends GridImpl.Dfs:
	var row_i: int
	var comp: RowComponent
	func _init(i: int, grid_: GridImpl) -> void:
		super(grid_)
		row_i = i
	func _cell_logic(i: int, _j: int, corner: E.Corner, cell: PureCell) -> bool:
		if cell.block_at(corner) or cell.air_at(corner):
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
	# flooded in order water or air. Each distinct componene MAY BE dependent.
	func _apply_strategy(_values: Array[ColComponent], _water_left: float, _nothing_left: float) -> bool:
		return GridModel.must_be_implemented()
	func _apply(j: int) -> bool:
		if grid.col_hints()[j].water_count < 0:
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
		var water_left := grid.col_hints()[j].water_count - grid.count_water_col(j)
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
	# Must be filled with water from left to right and air from right to left
	var cells: Array[CellPosition]
	func put_water_on(grid: GridImpl, count: float) -> void:
		for c in cells:
			count -= grid._pure_cell(c.i, c.j)._content_count_from(Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				grid.get_cell(c.i, c.j).put_water(c.corner, false)
				return
	func put_air_on(grid: GridImpl, count: float) -> void:
		for i in cells.size():
			var c: CellPosition = cells[-1 - i]
			count -= grid._pure_cell(c.i, c.j)._content_count_from(Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				(grid.get_cell(c.i, c.j) as GridImpl.CellWithLoc).put_air(c.corner, false, true)
				return

class ColDfs extends GridImpl.Dfs:
	var col_j: int
	var comp: ColComponent
	func _init(j: int, grid_: GridImpl) -> void:
		super(grid_)
		col_j = j
	func _cell_logic(i: int, j: int, corner: E.Corner, cell: PureCell) -> bool:
		if cell.block_at(corner) or cell.air_at(corner):
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
	static func description() -> String:
		return """
		- Put air in components that are too big
		- Put water everywhere if there's no more space for air
		"""
	func _apply_strategy(_i: int, values: Array[RowComponent], water_left: float, nothing_left: float) -> bool:
		if water_left == nothing_left:
			for comp in values:
				comp.put_water()
			return true
		var any := false
		for comp in values:
			if comp.size > water_left:
				comp.put_air()
				any = true
		return any

class MediumRowStrategy extends RowStrategy:
	static func description() -> String:
		return "If a component is so big it MUST be filled, fill it."
	func _apply_strategy(_i: int, values: Array[RowComponent], water_left: float, nothing_left: float) -> bool:
		var any := false
		for comp in values:
			if comp.size <= water_left and (nothing_left - comp.size) < water_left:
				comp.put_water()
				any = true
		return any

class AdvancedRowStrategy extends RowStrategy:
	static func description() -> String:
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
					cmp.put_air()
				any = true
		return any


class BasicColStrategy extends ColumnStrategy:
	static func description() -> String:
		return """
		- Put air partially in components that are bigger than the hint
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
				comp.put_air_on(grid, comp.size - water_left)
				any = true
		return any

class MediumColStrategy extends ColumnStrategy:
	static func description() -> String:
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
		if grid.col_hints()[j].water_count <= 0:
			return false
		var water_left := grid.col_hints()[j].water_count - grid.count_water_col(j)
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
				return grid.get_cell(single_i, j).put_air(single_corner, false, true)
		return false
	static func description() -> String:
		return "- If there's a single empty half-cell in the column, determine if it's water or air."

# This cell is empty and we could put water below it
static func _boat_possible(grid: GridImpl, i: int, j: int) -> bool:
	var c := grid._pure_cell(i, j)
	if c.cell_type() != E.CellType.Single:
		return false
	if c.water_full() or c.block_full() or grid.get_cell(i, j).wall_at(E.Walls.Bottom):
		return false
	c = grid._pure_cell(i + 1, j)
	return c._content_top() == Content.Water or c._content_top() == Content.Nothing

class BoatRowStrategy extends RowStrategy:
	static func description() -> String:
		return "If hint is all possible boat locations, then put the boats"
	func _apply(i: int) -> bool:
		var hint := grid._row_hints[i].boat_count
		if hint <= 0:
			return false
		var count := 0
		for j in grid.cols():
			if grid.get_cell(i, j).has_boat():
				hint -= 1
			elif SolverModel._boat_possible(grid, i, j):
				count += 1
		if hint > 0 and count == hint:
			var any := false
			for j in grid.cols():
				if !grid.get_cell(i, j).has_boat() and SolverModel._boat_possible(grid, i, j):
					if grid.get_cell(i, j).put_boat(false):
						any = true
			return any
		return false

# Aquariums that CAN and DO NOT have boats. The boat position might not be clear.
# Returns an array of (l, r), meaning ONE boat is possible on grid[l][j]..grid[r][j]
# If l != r means the boat position is not clear, as it may be placed in multiple places
# in the aquarium.
# This is best effort. Two separate aquariums might be unknowingly connected and the
# total possible boats might be smaller.
static func _list_possible_boats_on_col(grid: GridModel, j: int) -> Array[Vector2i]:
	var i := grid.rows() - 1
	var ans: Array[Vector2i] = []
	while i >= 0:
		if grid.get_cell(i, j).cell_type() != E.CellType.Single:
			i -= 1
			continue
		var boat_possible := SolverModel._boat_possible(grid, i, j)
		var had_boat := grid.get_cell(i, j).has_boat()
		if not boat_possible:
			i -= 1
			continue
		var r := i
		var l := i
		i -= 1
		# Skip rest of this aquarium. Best effort, they might still be connected through the side.
		while i >= 0 and grid.get_cell(i, j).cell_type() == E.CellType.Single and !grid.get_cell(i, j).wall_at(E.Walls.Bottom):
			assert(had_boat or l > i + 1 or not grid.get_cell(i, j).nothing_full() or SolverModel._boat_possible(grid, i, j))
			# Stop moving l when we see air
			if l == i + 1 and grid.get_cell(i, j).nothing_full():
				l = i
			i -= 1
		if not had_boat:
			ans.append(Vector2i(l, r))
	return ans

class BoatColStrategy extends ColumnStrategy:
	static func description() -> String:
		return "If hint is all possible aquariums, put boats in the ones where it's clear"
	func _apply(j: int) -> bool:
		var boats_left := grid.col_hints()[j].boat_count - grid.count_boat_col(j)
		if boats_left <= 0:
			return false
		var possible_boats := SolverModel._list_possible_boats_on_col(grid, j)
		if possible_boats.size() == boats_left:
			# We can put boats if the places they should go are clear
			var any := false
			for lr in possible_boats:
				if lr.x == lr.y:
					if grid.get_cell(lr.x, j).put_boat(false):
						any = true
			return any
		return false

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
	func _a_hints() -> Array[GridModel.LineHint]:
		return GridModel.must_be_implemented()
	func _count_water_a(_a: int) -> float:
		return GridModel.must_be_implemented()
	func _content(a: int, b2: int) -> Content:
		var c := _cell(a, b2 / 2).pure()
		return c._content_side(_right()) if bool(b2 & 1) else c._content_side(_left())
	func _corner(a: int, b2: int) -> E.Corner:
		return E.diag_to_corner(_cell(a, b2 / 2).cell_type(), _right() if bool(b2 & 1) else _left())
	func _wall_right(a: int, b2: int) -> bool:
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

# Logic for both row and column is the same, so let's make it generic
# Instead of (rows, cols) (i, j), let's use (a_len, b_len) (a, b)
class TogetherStrategy extends RowColStrategy:
	static func description() -> String:
		return """
		- If there's water in the {line}, far away cells can't have water
		- If there's water and its close to the border, we might need to expand it to the other side
		- If there's two waters in the {line}, they must be connected
		- If there's the space between two obstacles is less than N, then it can't have any water
		"""

	# Like the subset sum strategy on rows, but since it's required to be together, we actually
	# need only to use the two pointers technique to check all possible solutions
	# Assumes there's no water in this row/column
	func _add_necessary_waters_and_airs(a: int) -> bool:
		if _a_hints()[a].water_count <= 0.0:
			return false
		var any := false
		var hint := int(2 * _a_hints()[a].water_count)
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
				_cell(a, l2 / 2).put_air(_corner(a, l2), false, true)
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
		if _a_hints()[a].water_count_type != E.HintType.Together:
			return false
		var leftmost := 2 * _b_len()
		var rightmost := -1
		for b2 in 2 * _b_len():
			if _content(a, b2) == Content.Water:
				leftmost = min(leftmost, b2)
				rightmost = b2
		if rightmost == -1:
			return _add_necessary_waters_and_airs(a)
		var any := false
		# Merge all waters together
		for b2 in range(leftmost + 1, rightmost):
			var content := _content(a, b2)
			if content != Content.Water:
				any = true
				_cell(a, b2 / 2).put_water(_corner(a, b2), false)
		if any:
			return true
		if _a_hints()[a].water_count == -1.:
			# TODO: For {?} we still need to mark air on cells after/before block/air
			return any
		# Mark far away cells as empty
		var min_b2 := leftmost
		while min_b2 > 0 and _content(a, min_b2 - 1) == Content.Nothing:
			min_b2 -= 1
		var max_b2 := rightmost
		while max_b2 < 2 * _b_len() - 1 and _content(a, max_b2 + 1) == Content.Nothing:
			max_b2 += 1

		var water_left2 := int(2 * (_a_hints()[a].water_count - _count_water_a(a)))
		# Invalid solution
		if water_left2 < 0:
			return false
		var no_b2 := range(rightmost + water_left2 + 1, max_b2 + 1) # Far to the right
		no_b2.append_array(range(leftmost - water_left2 - 1, min_b2 - 1, -1)) # Far to the left
		no_b2.append_array(range(0, min_b2)) # Before block/air
		no_b2.append_array(range(max_b2 + 1, 2 * _b_len())) # After block/air
		for b2 in no_b2:
			if _content(a, b2) == Content.Nothing:
				any = true
				_cell(a, b2 / 2).put_air(_corner(a, b2), false, true)
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
	static func description() -> String:
		return TogetherStrategy.description().format({line = "row"})
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
	func _a_hints() -> Array[GridModel.LineHint]:
		return grid.row_hints()
	func _count_water_a(a: int) -> float:
		return grid.count_water_row(a)

class TogetherColStrategy extends TogetherStrategy:
	static func description() -> String:
		return TogetherStrategy.description().format({line = "column"})
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
	func _a_hints() -> Array[GridModel.LineHint]:
		return grid.col_hints()
	func _count_water_a(a: int) -> float:
		return grid.count_water_col(a)

class SeparateStrategy extends RowColStrategy:
	static func description() -> String:
		return """
		If adding water to a single cell would cause the waters to be together and
		fullfill the hint, we can't add water to that cell.
		"""

	func _apply(a: int) -> bool:
		if _a_hints()[a].water_count_type != E.HintType.Separated or _a_hints()[a].water_count == -1.:
			return false
		var water_left2 := int(2 * (_a_hints()[a].water_count - _count_water_a(a)))
		if water_left2 < 0:
			return false
		var leftmost := 2 * _b_len()
		var rightmost := -1
		var nothing_middle := 0
		for b2 in 2 * _b_len():
			if _content(a, b2) == Content.Water:
				leftmost = min(leftmost, b2)
				rightmost = b2
			if rightmost != -1 and _content(a, b2) == Content.Nothing:
				nothing_middle += 1
		var any := false
		if rightmost == -1:
			# We can mark connected components of size exactly the hint as air
			# because otherwise it would be together. This will work differently in rows and cols.
			for b2 in 2 * _b_len():
				if _content(a, b2) == Content.Nothing:
					# Hole is already discontinuous
					if rightmost != -1 and rightmost != b2 - 1:
						leftmost = -1
					leftmost = min(leftmost, b2)
					rightmost = b2
					if _will_flood_how_many(a, b2) == water_left2:
						_cell(a, b2 / 2).put_air(_corner(a, b2), false, true)
						any = true
			# Single hole, in which case it might be necessary to put water on the corners of it
			# to prevent creating a contiguous block of water
			if rightmost != -1 and leftmost != -1:
				var hole_sz := rightmost - leftmost + 1
				if _content(a, leftmost) == Content.Nothing and water_left2 == hole_sz - _will_flood_how_many(a, leftmost, true):
					_cell(a, leftmost / 2).put_water(_corner(a, leftmost), false)
					any = true
				if _content(a, rightmost) == Content.Nothing and water_left2 == hole_sz - _will_flood_how_many(a, rightmost, true):
					_cell(a, rightmost / 2).put_water(_corner(a, rightmost), false)
					any = true
			return any
		for b2 in range(leftmost + 1, rightmost):
			if _content(a, b2) != Content.Water:
				if nothing_middle == water_left2 and _content(a, b2) == Content.Nothing and _will_flood_how_many(a, b2) == water_left2:
					_cell(a, b2 / 2).put_air(_corner(a, b2), false, true)
					return true
				return false
		if _left() == E.Side.Top:
			# Walk up until we find a cell if we put water it will flood exactly water_left2
			var b2 := leftmost - 1
			while b2 >= 0 and _content(a, b2) == Content.Nothing:
				if bool(b2 & 1) and _cell(a, (b2 / 2)).cell_type() == E.CellType.Single:
					b2 -= 1
				if leftmost - b2 == water_left2:
					_cell(a, b2 / 2).put_air(_corner(a, b2), false, true)
					any = true
					break
				if leftmost - b2 > water_left2 or b2 == 0 or _wall_right(a, b2 - 1):
					break
				else:
					b2 -= 1
		else:
			if leftmost > 0 and _content(a, leftmost - 1) == Content.Nothing and _will_flood_how_many(a, leftmost - 1) == water_left2:
				_cell(a, (leftmost - 1) / 2).put_air(_corner(a, leftmost - 1), false, true)
				any = true
		if rightmost < _b_len() * 2 - 1 and _content(a, rightmost + 1) == Content.Nothing and _will_flood_how_many(a, rightmost + 1) == water_left2:
			_cell(a, (rightmost + 1) / 2).put_air(_corner(a, rightmost + 1), false, true)
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
	func _a_hints() -> Array[GridModel.LineHint]:
		return grid.row_hints()
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
	func _a_hints() -> Array[GridModel.LineHint]:
		return grid.col_hints()
	func _count_water_a(a: int) -> float:
		return grid.count_water_col(a)

class AllWatersEasyStrategy extends Strategy:
	static func description() -> String:
		return """
		- If remaining waters is 0, mark everything with air.
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
							if c.put_air(corner, false, true):
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
	static func description() -> String:
		return """
		- If flooding water on a tile would create too many waters, mark it with air.
		- Same for flooding air and adding water."""
	func apply_any() -> bool:
		if grid.grid_hints().total_water == -1.0:
			return false
		var water_left := grid.grid_hints().total_water - grid.count_waters()
		if water_left <= 0:
			return false
		var any := false
		for i in grid.rows():
			for j2 in 2 * grid.cols():
				var c := grid.get_cell(i, j2 / 2)
				var pc := grid._pure_cell(i, j2 / 2)
				var right := bool(j2 & 1)
				if (pc._content_right() if right else pc._content_right()) != GridImpl.Content.Nothing:
					continue
				# This if is just an optimisation since we only need to test this once on this line x aquarium
				if (right and c.cell_type() != E.CellType.Single) or (not right and c.wall_at(E.Walls.Left)):
					var corner: E.Corner = c.corners()[int(right)]
					if c.water_would_flood_how_many(corner) > water_left:
						if c.put_air(corner, false, true):
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
						if water_left > count_nothing - c.air_would_flood_how_many(corner):
							if c.put_water(corner, false):
								any = true
		return any

class AllBoatsStrategy extends Strategy:
	static func description() -> String:
		return "If all boat possible locations is the remaining hint, fill everything with boats."
	func apply_any() -> bool:
		var boats_left := grid.grid_hints().total_boats - grid.count_boats()
		if boats_left <= 0:
			return false
		var possible_boats: Array[Array] = []
		var total_possible := 0
		for j in grid.cols():
			var p := SolverModel._list_possible_boats_on_col(grid, j)
			total_possible += p.size()
			possible_boats.append(p)
		var any := false
		if total_possible == boats_left:
			for j in grid.cols():
				for lr in possible_boats[j]:
					if lr.x == lr.y:
						if grid.get_cell(lr.x, j).put_boat(false):
							any = true
		return any

const STRATEGY_LIST := {
	BasicRow = BasicRowStrategy,
	BasicCol = BasicColStrategy,
	BoatRow = BoatRowStrategy,
	BoatCol = BoatColStrategy,
	MediumRow = MediumRowStrategy,
	MediumCol = MediumColStrategy,
	AdvancedRow = AdvancedRowStrategy,
	AdvancedCol = AdvancedColStrategy,
	TogetherRow = TogetherRowStrategy,
	TogetherCol = TogetherColStrategy,
	SeparateRow = SeparateRowStrategy,
	SeparateCol = SeparateColStrategy,
	AllWatersEasy = AllWatersEasyStrategy,
	AllWatersMedium = AllWatersMediumStrategy,
	AllBoats = AllBoatsStrategy,
}

# Get a place in the solution that must have air and put a block on it
# This makes strategies easier to apply
func _put_block_on_air(grid: GridImpl) -> bool:
	for i in grid.rows():
		for j in grid.cols():
			var c := grid.get_cell(i, j)
			for corner in c.corners():
				var sol := grid._content_sol(i, j, corner)
				if c.nothing_at(corner) and (sol == GridImpl.Content.Air or sol == GridImpl.Content.Nothing):
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
		if not _put_block_on_air(grid):
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
	# Player may have left incomplete airs
	grid.flood_air(false)
	var strategies := {}
	for name in strategies_names:
		strategies[name] = STRATEGY_LIST[name].new(grid)
	for t in 50:
		var any := false
		for name in strategies_names:
			if strategies[name].apply_any():
				if t > 30:
					print("[%d] Applied %s" % [t, name])
				any = true
				# Earlier strategies are usually simpler, let's try to run them more
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
						c.put_air(corner, false)
						return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, min_boat_place, look_for_multiple))
					elif not look_for_multiple or r1 == SolveResult.SolvedMultiple or r1 == SolveResult.GaveUp:
						grid.redo()
						return r1
					# Otherwise we need to try to solve with air
					c.put_air(corner, true)
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
	# After we guessed all waters and airs, let's guess boats if we at least got the waters right
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
			if Vector2i(i, j) < min_boat_place or !SolverModel._boat_possible(grid, i, j) or grid.get_cell(i, j).has_boat():
				continue
			var c := grid.get_cell(i, j)
			var b := c.put_boat(true)
			assert(b)
			var r1 := full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, Vector2i(i, j + 1), look_for_multiple)
			grid.undo()
			if r1 == SolveResult.Unsolvable:
				return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, Vector2i(i, j + 1), look_for_multiple))
			elif not look_for_multiple or r1 == SolveResult.SolvedMultiple or r1 == SolveResult.GaveUp:
				grid.redo()
				return r1
			var r2 := full_solve(grid, strategy_list, cancel_sig, false, guesses_left - 1, Vector2i(i, j + 1), false)
			if r2 == SolveResult.Unsolvable:
				grid.undo()
				b = c.put_boat(false)
				assert(b)
				return _make_guess(full_solve(grid, strategy_list, cancel_sig, false, guesses_left, Vector2i(i, j + 1), look_for_multiple))
			return SolveResult.SolvedMultiple
	# Can't really guess anything else
	return SolveResult.Unsolvable
