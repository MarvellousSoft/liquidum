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
		if grid.hint_row(i) < 0:
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
		var water_left := grid.hint_row(i) - grid.count_water_row(i)
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
		print("[row] Put water on (%d, %d)" % [first.i, first.j])
		first.put_water(corner, false)
	func put_air() -> void:
		print("[col] Put air on (%d, %d)" % [first.i, first.j])
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
			comp.size += (1 + int(!cell.diag_wall)) * 0.5
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
		if grid.hint_col(j) < 0:
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
		var water_left := grid.hint_col(j) - grid.count_water_col(j)
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
		print("Looking for water count %f" % count)
		for c in cells:
			count -= grid._pure_cell(c.i, c.j)._content_count_from(GridImpl.Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				print("[col] Put water on (%d, %d)" % [c.i, c.j])
				grid.get_cell(c.i, c.j).put_water(c.corner, false)
				return
	func put_air_on(grid: GridImpl, count: float) -> void:
		print("Looking for air count %f" % count)
		for i in cells.size():
			var c: CellPosition = cells[-1 - i]
			count -= grid._pure_cell(c.i, c.j)._content_count_from(GridImpl.Content.Nothing, c.corner)
			if count < -0.5:
				push_error("Something's bad")
			if count <= 0:
				print("[col] Put air on (%d, %d)" % [c.i, c.j])
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
				print("[basic] Put water on comp of size %d" % comp.size)
				comp.put_water_on(grid, comp.size)
			return true
		var any := false
		for comp in values:
			if comp.size > water_left:
				print("[basic] Put air on %d/%d comp" % [comp.size - water_left, comp.size])
				comp.put_air_on(grid, comp.size - water_left)
				any = true
		return any

# If a component is so big it MUST be partially filled, fill it.
class MediumColStrategy extends ColumnStrategy:
	func _apply_strategy(values: Array[ColComponent], water_left: float, nothing_left: float) -> bool:
		var any := false
		for comp in values:
			if nothing_left - comp.size < water_left:
				print("[medium] Put water on %d/%d comp" % [water_left - (nothing_left - comp.size), comp.size])
				comp.put_water_on(grid, water_left - (nothing_left - comp.size))
				any = true
		return any

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
		MediumRowStrategy.new(grid),
		MediumColStrategy.new(grid),
		AdvancedRowStrategy.new(grid),
	]
	for _i in 50:
		if not strategies.any(func(s): return s.apply_any()):
			return
		print("1 pass")
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
func full_solve(grid: GridModel, flush_undo := true, look_for_multiple := true) -> SolveResult:
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
					var r2 := full_solve(grid, false, false)
					# It definitely had water
					if r2 == SolveResult.Unsolvable:
						grid.undo()
						c.put_water(corner, false)
						# TODO: Maybe here we could store the undo stack and reuse it
						# Doesn't really make it much faster
						return _make_guess(full_solve(grid, false))
					# Could solve both ways, definitely not unique
					return SolveResult.SolvedMultiple
	return SolveResult.Unsolvable
