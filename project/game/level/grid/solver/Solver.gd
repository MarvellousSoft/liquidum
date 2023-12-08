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

# This cell is empty and we could put water below it
static func _boat_possible(grid: GridImpl, i: int, j: int) -> bool:
	var c := grid._pure_cell(i, j)
	if c.cell_type() != E.CellType.Single:
		return false
	if c.water_full() or c.block_full() or grid.get_cell(i, j).wall_at(E.Walls.Bottom):
		return false
	c = grid._pure_cell(i + 1, j)
	return c._content_top() == Content.Water or c._content_top() == Content.Nothing

static func _put_boat(grid: GridImpl, i: int, j: int) -> void:
	# Put water down
	var c := grid.get_cell(i + 1, j)
	c.put_water(E.diag_to_corner(c.cell_type(), E.Side.Top), false)
	# Put boat here
	grid.get_cell(i, j).put_boat(false)

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
			for j in grid.cols():
				if !grid.get_cell(i, j).has_boat() and SolverModel._boat_possible(grid, i, j):
					SolverModel._put_boat(grid, i, j)
			return true
		return false

class BoatColStrategy extends ColumnStrategy:
	static func description() -> String:
		return "If hint is all possible aquariums, put boats in the ones where it's clear"
	func _apply(j: int) -> bool:
		var hint := grid._col_hints[j].boat_count
		if hint <= 0:
			return false
		var i := grid.rows() - 1
		# Aquariums that CAN have boats. The boat position might not be clear.
		var count := 0
		while i >= 0:
			if grid.get_cell(i, j).cell_type() != E.CellType.Single:
				i -= 1
				continue
			if grid.get_cell(i, j).has_boat():
				hint -= 1
			elif SolverModel._boat_possible(grid, i, j):
				count += 1
			else:
				i -= 1
				continue
			i -= 1
			# Skip rest of this aquarium. Best effort, they might still be connected through the side.
			while i >= 0 and grid.get_cell(i, j).cell_type() == E.CellType.Single and !grid.get_cell(i, j).wall_at(E.Walls.Bottom):
				i -= 1
		if hint > 0 and count == hint:
			# We can put boats if the places they should go are clear
			var any := false
			for i_ in range(grid.rows() - 1, -1, -1):
				i = i_
				if grid.get_cell(i, j).cell_type() != E.CellType.Single:
					continue
				if grid.get_cell(i, j).has_boat():
					continue
				if SolverModel._boat_possible(grid, i, j):
					if (!grid.get_cell(i, j).wall_at(E.Walls.Top) and SolverModel._boat_possible(grid, i - 1, j)) or SolverModel._boat_possible(grid, i + 1, j):
						continue
					SolverModel._put_boat(grid, i, j)
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
	func _will_flood_how_many(a: int, b2: int) -> int:
		if _content(a, b2) != Content.Nothing:
			return 0
		var b2_min := b2
		var b2_max := b2
		# Always floods right or down
		while not _wall_right(a, b2_max) and _content(a, b2_max + 1) == Content.Nothing:
			b2_max += 1
		# Only floods left, not up
		if _left() == E.Side.Left:
			while b2_min > 0 and not _wall_right(a, b2_min - 1) and _content(a, b2_min - 1) == Content.Nothing:
				b2_min -= 1
		# But up it still "floods" the same cell if it doesn't have a diagonal
		else:
			if bool(b2_min & 1) and _cell(a, (b2_min - 1) / 2).cell_type() == E.CellType.Single:
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
		"""

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
			return false
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
		if rightmost == -1:
			# We can mark connected components of size exactly the hint as air
			# because otherwise it would be together. This will work differently in rows and cols.
			var any_content := false
			for b2 in _b_len():
				if _content(a, b2) == Content.Nothing and _will_flood_how_many(a, b2) == water_left2:
					_cell(a, b2 / 2).put_air(_corner(a, b2), false, true)
					any_content = true
			return any_content
		for b2 in range(leftmost + 1, rightmost):
			if _content(a, b2) != Content.Water:
				if nothing_middle == water_left2 and _content(a, b2) == Content.Nothing and _will_flood_how_many(a, b2) == water_left2:
					_cell(a, b2 / 2).put_air(_corner(a, b2), false, true)
					return true
				return false
		var any := false
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

const STRATEGY_LIST := {
	BasicRow = BasicRowStrategy,
	BasicCol = BasicColStrategy,
	BoatRow = BoatRowStrategy,
	BoatCol = BoatColStrategy,
	MediumRow = MediumRowStrategy,
	MediumCol = MediumColStrategy,
	AdvancedRow = AdvancedRowStrategy,
	TogetherRow = TogetherRowStrategy,
	TogetherCol = TogetherColStrategy,
	SeparateRow = SeparateRowStrategy,
	SeparateCol = SeparateColStrategy,
}

func can_solve_with_strategies(grid: GridModel, strategies_names: Array, forced_strategies_or: Array, flush_undo := true) -> bool:
	for s in forced_strategies_or:
		if strategies_names.find(s) == -1:
			strategies_names.append(s)
	var need_undo := apply_strategies(grid, strategies_names, flush_undo)
	if grid.are_hints_satisfied():
		if forced_strategies_or.is_empty():
			return true
		if need_undo:
			grid.undo()
		apply_strategies(grid, strategies_names.filter(func(s2): return forced_strategies_or.find(s2) == -1), false)
		return not grid.are_hints_satisfied()
	else:
		return false

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

enum SolveResult { SolvedUniqueNoGuess, SolvedUnique, SolvedMultiple, Unsolvable }


func _make_guess(res: SolveResult) -> SolveResult:
	match res:
		SolveResult.SolvedUniqueNoGuess:
			return SolveResult.SolvedUnique
		_:
			return res

# Will apply strategies but also try to guess
# If look_for_multiple = false, will not try to look for multiple solutions
func full_solve(grid: GridModel, strategy_list: Array, flush_undo := true, min_boat_place := Vector2i.ZERO, look_for_multiple := true) -> SolveResult:
	assert(grid.editor_mode() and not grid.auto_update_hints())
	if flush_undo:
		grid.push_empty_undo()
	apply_strategies(grid, strategy_list, false)
	if grid.is_any_hint_broken():
		#grid.copy_to_clipboard()
		return SolveResult.Unsolvable
	if grid.are_hints_satisfied(true):
		return SolveResult.SolvedUniqueNoGuess
	for i in grid.rows():
		for j in grid.cols():
			for corner in E.Corner.values():
				var c := grid.get_cell(i, j)
				if c.nothing_at(corner):
					# New undo stack
					c.put_water(corner, true)
					var r1 := full_solve(grid, strategy_list, false)
					grid.undo()
					# Unsolvable means there's definitely no water here. Tail recurse.
					if r1 == SolveResult.Unsolvable:
						c.put_air(corner, false)
						return _make_guess(full_solve(grid, strategy_list, false))
					elif not look_for_multiple or r1 == SolveResult.SolvedMultiple:
						grid.redo()
						return r1
					# Otherwise we need to try to solve with air
					c.put_air(corner, true)
					var r2 := full_solve(grid, strategy_list, false, min_boat_place, false)
					# It definitely had water
					if r2 == SolveResult.Unsolvable:
						grid.undo()
						c.put_water(corner, false)
						# TODO: Maybe here we could store the undo stack and reuse it
						# Doesn't really make it much faster
						return _make_guess(full_solve(grid, strategy_list, false))
					# Could solve both ways, definitely not unique
					return SolveResult.SolvedMultiple
	# After we guessed all waters and airs, let's guess boats if we at least got the waters right
	for i in grid.rows():
		if grid.get_row_hint_status(i, E.HintContent.Water) == E.HintStatus.Wrong:
			return SolveResult.Unsolvable 
	for j in grid.cols():
		if grid.get_col_hint_status(j, E.HintContent.Water) == E.HintStatus.Wrong:
			return SolveResult.Unsolvable
	for i in grid.rows():
		for j in grid.cols():
			if Vector2i(i, j) < min_boat_place or !SolverModel._boat_possible(grid, i, j):
				continue
			var c := grid.get_cell(i, j)
			c.put_boat(true)
			var r1 := full_solve(grid, strategy_list, false, Vector2i(i, j + 1))
			grid.undo()
			if r1 == SolveResult.Unsolvable:
				return _make_guess(full_solve(grid, strategy_list, false, Vector2i(i, j + 1)))
			elif not look_for_multiple or r1 == SolveResult.SolvedMultiple:
				grid.redo()
				return r1
			var r2 := full_solve(grid, strategy_list, false, Vector2i(i, j + 1), false)
			if r2 == SolveResult.Unsolvable:
				grid.undo()
				c.put_boat(false)
				return _make_guess(full_solve(grid, strategy_list, false, Vector2i(i, j + 1)))
			return SolveResult.SolvedMultiple
	# Can't really guess anything else
	return SolveResult.Unsolvable
