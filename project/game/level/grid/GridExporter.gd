class_name GridExporter

# Change when there's breaking changes
const SAVE_VERSION := 1

func _export_pure_cell(pure: GridImpl.PureCell) -> Dictionary:
	return {
		c_left = pure.c_left,
		c_right = pure.c_right,
		cell_type = pure.cell_type(),
	}

func _load_pure_cell(data: Dictionary) -> GridImpl.PureCell:
	var cell := GridImpl.PureCell.empty()
	cell.c_left = data.c_left
	cell.c_right = data.c_right
	cell.type = data.cell_type
	return cell

func _export_grid(grid: Array[Array], inner_export: Callable) -> Array:
	var exported: Array = []
	for i in grid.size():
		var exported_row: Array = []
		for j in grid[i].size():
			exported_row.append(inner_export.call(grid[i][j]))
		exported.append(exported_row)
	return exported

func _load_grid(data: Array, inner_load: Callable) -> Array[Array]:
	var grid: Array[Array] = []
	for row in data:
		var new_row: Array = []
		for cell_data in row:
			var cell = inner_load.call(cell_data)
			new_row.append(cell)
		grid.append(new_row)
	return grid

func _export_line_hint(line: GridModel.LineHint) -> Dictionary:
	return {
		water_count = line.water_count,
		water_count_type = line.water_count_type,
		boat_count = line.boat_count,
		boat_count_type = line.boat_count_type,
	}

func _load_line_hint(data: Dictionary) -> GridModel.LineHint:
	var hint := GridModel.LineHint.new()
	hint.water_count = data.water_count
	hint.water_count_type = data.water_count_type
	hint.boat_count = data.boat_count
	hint.boat_count_type = data.boat_count_type
	return hint

func _export_bool(b: bool) -> int:
	return int(b)

func _load_bool(b: int) -> bool:
	return b != 0

func _export_grid_hints(hints: GridModel.GridHints) -> Dictionary:
	return {
		total_water = hints.total_water,
		total_boats = hints.total_boats,
		expected_aquariums = hints.expected_aquariums,
	}

func _load_grid_hints(data: Dictionary) -> GridModel.GridHints:
	var hints := GridModel.GridHints.new()
	hints.total_water = float(data.total_water)
	hints.total_boats = int(data.total_boats)
	hints.expected_aquariums.assign(data.expected_aquariums)
	return hints

func export_data(grid: GridImpl) -> Dictionary:
	return {
		version = SAVE_VERSION,
		cells = _export_grid(grid.pure_cells, _export_pure_cell),
		row_hints = grid._row_hints.map(_export_line_hint),
		col_hints = grid._col_hints.map(_export_line_hint),

		wall_bottom = _export_grid(grid.wall_bottom, _export_bool),
		wall_right = _export_grid(grid.wall_right, _export_bool),
		grid_hints = _export_grid_hints(grid._grid_hints),
	}

func load_data(data: Dictionary, load_mode: GridModel.LoadMode) -> GridImpl:
	if SAVE_VERSION != data.version:
		push_warning("Invalid version")
	var grid := GridImpl.new(0, 0)
	grid.pure_cells = _load_grid(data.cells, _load_pure_cell)
	var n := grid.pure_cells.size()
	var m := 0 if n == 0 else grid.pure_cells[0].size()
	grid.n = n
	grid.m = m
	grid._row_hints.assign(data.row_hints.map(_load_line_hint))
	grid._col_hints.assign(data.col_hints.map(_load_line_hint))
	grid.wall_bottom = _load_grid(data.wall_bottom, _load_bool)
	grid.wall_right = _load_grid(data.wall_right, _load_bool)
	grid._grid_hints = _load_grid_hints(data.grid_hints)
	grid._finish_loading(load_mode)
	return grid
