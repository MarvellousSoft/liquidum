class_name SolverModel

class Strategy:
	func apply_any() -> bool:
		return GridModel.must_be_implemented()

# Strategy for a single row
class RowStrategy extends Strategy:
	var grid: GridImpl
	func _init(grid_: GridImpl) -> void:
		grid = grid_
	# values is an array of component, that is, all triangles
	# are in the same aquarium. Each of the triangles in the component MUST be
	# flooded all at once with water or air. Each distinct componene IS completely
	# independent.
	func _apply_strategy(_values: Array[RowComponent], _water_left: float, _nothing_left: float) -> bool:
		return GridModel.must_be_implemented()
	func _apply(i: int) -> bool:
		if grid.row_hints()[i].water_count < 0:
			return false
		var dfs := RowDfs.new(i, grid)
		var last_seen := grid.last_seen
		var comps: Array[RowComponent] = []
		for j in grid.cols():
			for corner in E.Corner.values():
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
		return self._apply_strategy(comps, water_left, nothing_left)
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
	var grid: GridImpl
	func _init(grid_: GridImpl) -> void:
		grid = grid_
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
			count -= grid._pure_cell(c.i, c.j)._content_count_from(GridImpl.Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				grid.get_cell(c.i, c.j).put_water(c.corner, false)
				return
	func put_air_on(grid: GridImpl, count: float) -> void:
		for i in cells.size():
			var c: CellPosition = cells[-1 - i]
			count -= grid._pure_cell(c.i, c.j)._content_count_from(GridImpl.Content.Nothing, c.corner)
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
		var nothing := cell._content_count_from(GridImpl.Content.Nothing, corner)
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

# - Put air in components that are too big
# - Put water everywhere if there's no more space for air
class BasicRowStrategy extends RowStrategy:
	func _apply_strategy(values: Array[RowComponent], water_left: float, nothing_left: float) -> bool:
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

# If a component is so big it MUST be filled, fill it.
class MediumRowStrategy extends RowStrategy:
	func _apply_strategy(values: Array[RowComponent], water_left: float, nothing_left: float) -> bool:
		var any := false
		for comp in values:
			if comp.size <= water_left and (nothing_left - comp.size) < water_left:
				comp.put_water()
				any = true
		return any

# Use subset sum to tell if some components MUST or CANT be present in the solution
class AdvancedRowStrategy extends RowStrategy:
	func _apply_strategy(values: Array[RowComponent], water_left: float, _nothing_left: float) -> bool:
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

# - Put air partially in components that are too big
# - Put water everywhere if there's no more space for non-water
class BasicColStrategy extends ColumnStrategy:
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

# If a component is so big it MUST be partially filled, fill it.
class MediumColStrategy extends ColumnStrategy:
	func _apply_strategy(values: Array[ColComponent], water_left: float, nothing_left: float) -> bool:
		var any := false
		for comp in values:
			if nothing_left - comp.size < water_left:
				comp.put_water_on(grid, water_left - (nothing_left - comp.size))
				any = true
		return any

static func _boat_possible(grid: GridImpl, i: int, j: int) -> bool:
	var c := grid._pure_cell(i, j)
	if c.cell_type() != E.CellType.Single:
		return false
	if c.water_full() or c.block_full() or grid.get_cell(i, j).wall_at(E.Walls.Bottom):
		return false
	c = grid._pure_cell(i + 1, j)
	return c._content_top() == GridImpl.Content.Water or c._content_top() == GridImpl.Content.Nothing

static func _put_boat(grid: GridImpl, i: int, j: int) -> void:
	# Put water down
	var c := grid.get_cell(i + 1, j)
	c.put_water(E.diag_to_corner(c.cell_type(), E.Side.Top), false)
	# Put boat here
	grid.get_cell(i, j).put_boat(false)

# If hint is all possible boat locations, then put the boats
class BoatRowStrategy extends RowStrategy:
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
	func _apply(j: int) -> bool:
		var hint := grid._col_hints[j].boat_count
		if hint <= 0:
			return false
		var i := grid.rows() - 1
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

# Tries to solve the puzzle as much as possible
func apply_strategies(grid: GridModel, flush_undo := true) -> void:
	# We'll merge all changes in the same undo here
	if flush_undo:
		grid.push_empty_undo()
	# Player may have left incomplete airs
	grid.flood_air(false)
	var strategies: Array[Strategy] = [
		BasicRowStrategy.new(grid),
		BasicColStrategy.new(grid),
		BoatRowStrategy.new(grid),
		BoatColStrategy.new(grid),
		MediumRowStrategy.new(grid),
		MediumColStrategy.new(grid),
		AdvancedRowStrategy.new(grid),
	]
	for _i in 50:
		if not strategies.any(func(s): return s.apply_any()):
			return
		assert(_i < 40)

enum SolveResult { SolvedUniqueNoGuess, SolvedUnique, SolvedMultiple, Unsolvable }

func _make_guess(res: SolveResult) -> SolveResult:
	match res:
		SolveResult.SolvedUniqueNoGuess:
			return SolveResult.SolvedUnique
		_:
			return res

# Will apply strategies but also try to guess
# If look_for_multiple = false, will not try to look for multiple solutions
func full_solve(grid: GridModel, flush_undo := true, min_boat_place := Vector2i.ZERO, look_for_multiple := true) -> SolveResult:
	if flush_undo:
		grid.push_empty_undo()
	apply_strategies(grid, false)
	if grid.is_any_hint_broken():
		return SolveResult.Unsolvable
	if grid.are_hints_satisfied():
		return SolveResult.SolvedUniqueNoGuess
	for i in grid.rows():
		for j in grid.cols():
			for corner in E.Corner.values():
				var c := grid.get_cell(i, j)
				if c.nothing_at(corner):
					# New undo stack
					c.put_water(corner, true)
					var r1 := full_solve(grid, false)
					grid.undo()
					# Unsolvable means there's definitely no water here. Tail recurse.
					if r1 == SolveResult.Unsolvable:
						c.put_air(corner, false)
						return _make_guess(full_solve(grid, false))
					elif not look_for_multiple:
						grid.redo()
						return r1
					# Otherwise we need to try to solve with air
					c.put_air(corner, true)
					var r2 := full_solve(grid, false, min_boat_place, false)
					# It definitely had water
					if r2 == SolveResult.Unsolvable:
						grid.undo()
						c.put_water(corner, false)
						# TODO: Maybe here we could store the undo stack and reuse it
						# Doesn't really make it much faster
						return _make_guess(full_solve(grid, false))
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
			var r1 := full_solve(grid, false, Vector2i(i, j + 1))
			grid.undo()
			if r1 == SolveResult.Unsolvable:
				return _make_guess(full_solve(grid, false, Vector2i(i, j + 1)))
			elif not look_for_multiple:
				grid.redo()
				return r1
			var r2 := full_solve(grid, false, Vector2i(i, j + 1), false)
			if r2 == SolveResult.Unsolvable:
				grid.undo()
				c.put_boat(false)
				return _make_guess(full_solve(grid, false, Vector2i(i, j + 1)))
			return SolveResult.SolvedMultiple
	# Can't really guess anything else
	return SolveResult.Unsolvable
