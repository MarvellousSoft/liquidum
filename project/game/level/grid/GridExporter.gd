class_name GridExporter

# Change when there's breaking changes
const SAVE_VERSION := 1

# Use ints to save serialization space
# We're not human-editing this anyway
enum {version, c_left, c_right, cell_type, water_count, water_count_type, boat_count, boat_count_type,
total_water, total_boats, expected_aquariums, row_hints, col_hints, cells, wall_bottom, wall_right,
grid_hints}

func _export_pure_cell(pure: GridImpl.PureCell) -> Dictionary:
	return {
		c_left: pure.c_left,
		c_right: pure.c_right,
		cell_type: pure.cell_type(),
	}

func _load_pure_cell(data: Dictionary) -> GridImpl.PureCell:
	var cell := GridImpl.PureCell.empty()
	cell.c_left = data[c_left]
	cell.c_right = data[c_right]
	cell.type = data[cell_type]
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
		water_count: line.water_count,
		water_count_type: line.water_count_type,
		boat_count: line.boat_count,
		boat_count_type: line.boat_count_type,
	}

func _load_line_hint(data: Dictionary) -> GridModel.LineHint:
	var hint := GridModel.LineHint.new()
	hint.water_count = data[water_count]
	hint.water_count_type = data[water_count_type]
	hint.boat_count = data[boat_count]
	hint.boat_count_type = data[boat_count_type]
	return hint

func _export_bool(b: bool) -> int:
	return int(b)

func _load_bool(b: int) -> bool:
	return b != 0

func _export_grid_hints(hints: GridModel.GridHints) -> Dictionary:
	return {
		total_water: hints.total_water,
		total_boats: hints.total_boats,
		expected_aquariums: hints.expected_aquariums,
	}

func _load_grid_hints(data: Dictionary) -> GridModel.GridHints:
	var hints := GridModel.GridHints.new()
	hints.total_water = float(data[total_water])
	hints.total_boats = int(data[total_boats])
	# Need to convert keys to floats
	for size in data[expected_aquariums]:
		hints.expected_aquariums[float(size)] = int(data[expected_aquariums][size])
	return hints

func export_data(grid: GridImpl) -> Dictionary:
	return {
		version: SAVE_VERSION,
		cells: _export_grid(grid.pure_cells, _export_pure_cell),
		row_hints: grid._row_hints.map(_export_line_hint),
		col_hints: grid._col_hints.map(_export_line_hint),

		wall_bottom: _export_grid(grid.wall_bottom, _export_bool),
		wall_right: _export_grid(grid.wall_right, _export_bool),
		grid_hints: _export_grid_hints(grid._grid_hints),
	}

func _convert_keys_to_int(data_: Variant) -> Variant:
	if data_ is Array:
		for i in data_.size():
			data_[i] = _convert_keys_to_int(data_[i])
	if not data_ is Dictionary:
		return data_
	var data: Dictionary = data_
	for key in data.keys():
		if key is String and key.is_valid_int():
			var tmp = _convert_keys_to_int(data[key])
			data.erase(key)
			data[key.to_int()] = tmp
	return data

func load_compatible_content(old_content: GridImpl.Content, new_content: GridImpl.Content) -> bool:
	# Only non-compatible case is blocks since that's not really up to the user to change
	if old_content == GridImpl.Content.Block:
		return new_content == GridImpl.Content.Block
	return true

func load_compatible_cell(old_cell: GridImpl.PureCell, new_cell: GridImpl.PureCell) -> bool:
	if new_cell.cell_type() == E.Single and new_cell.c_left != new_cell.c_right:
		return false
	return old_cell.cell_type() == new_cell.cell_type() and load_compatible_content(old_cell.c_left, old_cell.c_right) \
	  and load_compatible_content(old_cell.c_right, new_cell.c_right)

func load_compatible(old_grid: GridImpl, data: Dictionary, new_cells: Array[Array]) -> bool:
	var old_cells := old_grid.pure_cells
	if old_cells.size() != new_cells.size():
		return false
	for i in old_cells.size():
		if old_cells[i].size() != new_cells[i].size():
			return false
		for j in old_cells[i].size():
			if not (new_cells[i][j] is GridImpl.PureCell) or not load_compatible_cell(old_cells[i][j], new_cells[i][j]):
				return false
	if old_grid.wall_bottom != _load_grid(data[wall_bottom], _load_bool):
		return false
	if old_grid.wall_right != _load_grid(data[wall_right], _load_bool):
		return false
	return true

func load_data(grid: GridImpl, data: Dictionary, load_mode: GridModel.LoadMode) -> GridImpl:
	data = _convert_keys_to_int(data)
	if SAVE_VERSION != data[version]:
		push_warning("Invalid version")
	var content_only := (load_mode == GridModel.LoadMode.ContentOnly)
	var new_cells := _load_grid(data[cells], _load_pure_cell)
	if content_only and not load_compatible(grid, data, new_cells):
		push_warning("Invalid save. Ignoring it and defaulting to empty grid.")
		return grid
	grid.pure_cells = new_cells
	var n := grid.pure_cells.size()
	var m := 0 if n == 0 else grid.pure_cells[0].size()
	if content_only:
		assert(grid.n == n)
		assert(grid.m == m)
	else:
		grid.n = n
		grid.m = m
		grid._row_hints.assign(data[row_hints].map(_load_line_hint))
		grid._col_hints.assign(data[col_hints].map(_load_line_hint))
		grid.wall_bottom = _load_grid(data[wall_bottom], _load_bool)
		grid.wall_right = _load_grid(data[wall_right], _load_bool)
		grid._grid_hints = _load_grid_hints(data[grid_hints])
	grid._finish_loading(load_mode)
	return grid
