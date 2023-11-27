class_name GridView
extends Control


signal updated
signal mistake_made
signal updated_size

const STARTUP_DELAY = 0.1
const REGULAR_CELL = preload("res://game/level/cells/RegularCell.tscn")
const CELL_CORNER = preload("res://game/level/cells/CellCorner.tscn")
const PREVIEW_DRAG_COLORS = {
	"adding": Color("#61fc89df"),
	"removing": Color("#ff6464df"),
}
const MIN_GRID_R = 1
const MAX_GRID_R = 10
const MIN_GRID_C = 1
const MAX_GRID_C = 10

@onready var MainGridCont = $CenterContainer/MainGridContainer
@onready var GridCont = $CenterContainer/MainGridContainer/GridContainer
@onready var Columns = $CenterContainer/MainGridContainer/GridContainer/Columns
@onready var HintBars = {
	"top": $CenterContainer/MainGridContainer/GridContainer/HintBarTop,
	"left": $CenterContainer/MainGridContainer/GridContainer/HintBarLeft,
}
@onready var CellCornerGrid = $CellCornerGrid
@onready var DragPreview = $DragPreviewCanvas/DragPreviewLine
@onready var EditColumnSize = %EditColumnSize
@onready var EditRowSize = %EditRowSize
@onready var FillerPanel = %FillerPanel

var brush_mode : E.BrushMode = E.BrushMode.Water
var grid_logic : GridModel
var rows : int
var columns : int
var mouse_hold_status : E.MouseDragState = E.MouseDragState.None
var previous_wall_index := []
var editor_mode := false
var wall_brush_active := false

func _ready():
	reset()


func _process(_dt):
	update_drag_preview()


func _input(event):
	if event is InputEventMouseButton:
		if not event.pressed:
			mouse_hold_status = E.MouseDragState.None
			previous_wall_index = []
	elif grid_logic and event.is_action_pressed(&"undo"):
		grid_logic.undo()
		update()
	elif grid_logic and event.is_action_pressed(&"redo"):
		grid_logic.redo()
		update()


func reset() -> void:
	for child in Columns.get_children():
		Columns.remove_child(child)
	for child in CellCornerGrid.get_children():
		CellCornerGrid.remove_child(child)


func setup(grid_logic_: GridModel) -> void:
	grid_logic = grid_logic_
	editor_mode = grid_logic.editor_mode()
	rows = grid_logic.rows()
	columns = grid_logic.cols()
	for node in [EditColumnSize, EditRowSize, FillerPanel]:
		node.visible = editor_mode
	reset()
	for i in rows:
		var new_row = HBoxContainer.new()
		new_row.add_theme_constant_override("separation", 0)
		Columns.add_child(new_row)
		for j in columns:
			var cell_data = grid_logic.get_cell(i, j)
			create_cell(new_row, cell_data, i, j)

	setup_hints()
	setup_cell_corners()
	update()
	if not editor_mode:
		disable()
		var sample_cell = get_cell(0,0)
		var delay = (rows+1)*columns*sample_cell.STARTUP_DELAY
		await get_tree().create_timer(delay).timeout
		enable()

#Assumes grid_logic is already setup
func setup_hints():
	assert(grid_logic, "Grid Logic not properly set to setup grid hints")
	HintBars.top.setup(grid_logic.col_hints(), editor_mode)
	HintBars.left.setup(grid_logic.row_hints(), editor_mode)
	var delay = STARTUP_DELAY * (rows + 1) * columns
	HintBars.left.startup(editor_mode, delay + STARTUP_DELAY)
	HintBars.top.startup(editor_mode, delay + STARTUP_DELAY*2)


func setup_cell_corners() -> void:
	await get_tree().process_frame
	for child in CellCornerGrid.get_children():
		CellCornerGrid.remove_child(child)
	var sample_cell = get_cell(0,0)
	var sample_corner = CELL_CORNER.instantiate()
	CellCornerGrid.columns = columns + 1
	CellCornerGrid.global_position = sample_cell.global_position
	CellCornerGrid.position.x -= sample_corner.size.x/2
	CellCornerGrid.position.y -= sample_corner.size.y/2
	CellCornerGrid.add_theme_constant_override("h_separation", sample_cell.size.x - sample_corner.size.x)
	CellCornerGrid.add_theme_constant_override("v_separation", sample_cell.size.y - sample_corner.size.y)
	for i in rows + 1:
		for j in columns + 1:
			var corner = CELL_CORNER.instantiate()
			CellCornerGrid.add_child(corner)
			corner.setup(i, j)
			corner.pressed_main_button.connect(_on_cell_corner_pressed_main_button)
			corner.pressed_second_button.connect(_on_cell_corner_pressed_second_button)
			corner.mouse_entered_button.connect(_on_cell_corner_mouse_entered)
	
	if not wall_brush_active:
		disable_wall_editor()
	else:
		enable_wall_editor()


func enable() -> void:
	for i in rows:
		for j in columns:
			get_cell(i, j).enable()


func disable() -> void:
	for i in rows:
		for j in columns:
			get_cell(i, j).disable()


func get_grid_size() -> Vector2:
	return MainGridCont.size


func apply_strategies(strategies: Array, flush_undo := true, do_emit_signal := true) -> void:
	SolverModel.new().apply_strategies(grid_logic, strategies, flush_undo)
	update(do_emit_signal)

func full_solve(strategies: Array, flush_undo := true, do_emit_signal := true) -> SolverModel.SolveResult:
	grid_logic.force_editor_mode(true)
	var result := SolverModel.new().full_solve(grid_logic, strategies, flush_undo)
	grid_logic.force_editor_mode(false)
	update(do_emit_signal)
	return result


func set_brush_mode(mode : E.BrushMode) -> void:
	brush_mode = mode
	if mode == E.BrushMode.Wall:
		wall_brush_active = true
		enable_wall_editor()
	else:
		wall_brush_active = false
		disable_wall_editor()


func get_expected_waters() -> float:
	return grid_logic.get_expected_waters()


func get_expected_boats() -> int:
	return grid_logic.get_expected_boats()

#Assumes the expected waters is >= 0
func get_missing_waters() -> float:
	return grid_logic.get_expected_waters() - grid_logic.count_waters()


func get_missing_boats() -> int:
	return grid_logic.get_expected_boats() - grid_logic.count_boats()


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)

	cell.setup(self, cell_data, n, m, editor_mode)
	
	cell.pressed_main_button.connect(_on_cell_pressed_main_button)
	cell.pressed_second_button.connect(_on_cell_pressed_second_button)
	cell.mouse_entered.connect(_on_cell_mouse_entered)
	
	return cell


func update(do_emit_signal := true, fast_update := false) -> void:
	if grid_logic.rows() != rows or grid_logic.cols() != columns:
		setup(grid_logic)
	else:
		update_walls()
		update_visuals(fast_update)
		update_hints()
	if do_emit_signal:
		updated.emit()


func is_level_finished():
	return grid_logic.are_hints_satisfied()

func update_walls() -> void:
	for i in rows:
		for j in columns:
			var cell_data := grid_logic.get_cell(i, j)
			var cell := get_cell(i, j) as Cell
			cell.copy_data(cell_data)

func update_visuals(fast_update := false) -> void:
	for i in rows:
		for j in columns:
			var cell_data := grid_logic.get_cell(i, j)
			var cell := get_cell(i, j) as Cell
			if cell_data.water_full():
				cell.remove_air()
				cell.set_boat(false)
				cell.set_water(E.Single, true)
			elif cell_data.air_full():
				cell.remove_water()
				cell.set_boat(false)
				cell.set_air(E.Single, true)
			elif cell_data.has_boat():
				cell.remove_water()
				cell.remove_air()
				cell.set_boat(true)
			elif cell_data.nothing_full():
				cell.remove_water()
				cell.remove_air()
				cell.set_boat(false)
			else:
				for corner in E.Corner.values():
					cell.set_water(corner, cell_data.water_at(corner))
					cell.set_air(corner, cell_data.air_at(corner))
			if fast_update:
				cell.fast_update_waters()


func update_hints() -> void:
	var row_hints := grid_logic.row_hints()
	for i in rows:
		for hint_type in [E.HintContent.Water, E.HintContent.Boat]:
			var hint = HintBars.left.get_hint(i, hint_type == E.HintContent.Boat)
			if hint:
				var val := float(row_hints[i].boat_count) if hint_type == E.HintContent.Boat else row_hints[i].water_count
				hint.set_value(val)
				hint.set_hint_type(row_hints[i].boat_count_type if hint_type == E.HintContent.Boat else row_hints[i].water_count_type)
				if not editor_mode:
					hint.set_status(grid_logic.get_row_hint_status(i, hint_type))
				else:
					hint.set_status(E.HintStatus.Normal)
	var col_hints := grid_logic.col_hints()
	for j in columns:
		for hint_type in [E.HintContent.Water, E.HintContent.Boat]:
			var hint = HintBars.top.get_hint(j, hint_type == E.HintContent.Boat)
			if hint:
				var val := float(col_hints[j].boat_count) if hint_type == E.HintContent.Boat else col_hints[j].water_count
				hint.set_value(val)
				hint.set_hint_type(col_hints[j].boat_count_type if hint_type == E.HintContent.Boat else col_hints[j].water_count_type)
				if not editor_mode:
					hint.set_status(grid_logic.get_col_hint_status(j, hint_type))
				else:
					hint.set_status(E.HintStatus.Normal)


func set_counters_visibility(row: Array[int], col: Array[int]) -> void:
	HintBars.left.set_visibility(row)
	HintBars.top.set_visibility(col)

func get_cell(i: int, j: int) -> Node:
	return Columns.get_child(i).get_child(j)

func col_hints_should_be_visible() -> Array[int]:
	return HintBars.top.should_be_visible()

func row_hints_should_be_visible() -> Array[int]:
	return HintBars.left.should_be_visible()


func _connections_down(i: int, j: int, corner: E.Waters) -> Array[int]:
	var conns: Array[int] = []
	var single := (corner == E.Waters.Single)
	# Check down
	if !grid_logic.wall_at(i, j, E.Side.Bottom) and (single or !E.corner_is_top(corner as E.Corner)):
		conns.append(j)
	# Check down right
	if !grid_logic.wall_at(i, j, E.Side.Right) and (single or !E.corner_is_left(corner as E.Corner)):
		var c := grid_logic.get_cell(i, j + 1)
		if !c.wall_at(E.Walls.IncDiag) and !c.wall_at(E.Walls.Bottom):
			conns.append(j + 1)
	# Check down left
	if !grid_logic.wall_at(i, j, E.Side.Left) and (single or E.corner_is_left(corner as E.Corner)):
		var c := grid_logic.get_cell(i, j - 1)
		if !c.wall_at(E.Walls.DecDiag) and !c.wall_at(E.Walls.Bottom):
			conns.append(j - 1)
	return conns

func _connections_up(i: int, j: int, corner: E.Waters) -> Array[int]:
	var conns: Array[int] = []
	var single := (corner == E.Waters.Single)
	# Check down
	if !grid_logic.wall_at(i, j, E.Side.Top) and (single or E.corner_is_top(corner as E.Corner)):
		conns.append(j)
	# Check up right
	if !grid_logic.wall_at(i, j, E.Side.Right) and (single or !E.corner_is_left(corner as E.Corner)):
		var c := grid_logic.get_cell(i, j + 1)
		if !c.wall_at(E.Walls.DecDiag) and !c.wall_at(E.Walls.Top):
			conns.append(j + 1)
	# Check up left
	if !grid_logic.wall_at(i, j, E.Side.Left) and (single or E.corner_is_left(corner as E.Corner)):
		var c := grid_logic.get_cell(i, j - 1)
		if !c.wall_at(E.Walls.IncDiag) and !c.wall_at(E.Walls.Top):
			conns.append(j - 1)
	return conns

func can_increase_water(i: int, j: int, corner: E.Waters) -> bool:
	var conns := _connections_down(i, j, corner)
	for dj in conns:
		var any := [E.Waters.Single, E.Waters.TopLeft, E.Waters.TopRight].any(func(c):
			return get_cell(i + 1, dj).get_corner_water_level(c) >= 1.0)
		if not any:
			return false
	return true


func can_decrease_water(i : int, j : int, corner : E.Waters):
	var conns := _connections_up(i, j, corner)
	for dj in conns:
		for c in [E.Waters.Single, E.Waters.BottomLeft, E.Waters.BottomRight]:
			if get_cell(i - 1, dj).get_corner_water_level(c) > 0.0:
				return false
	return true


func is_at_surface(i: int, j: int, corner: E.Waters) -> bool:
	var conns := _connections_up(i, j, corner)
	for dj in conns:
		for c in [E.Waters.Single, E.Waters.BottomLeft, E.Waters.BottomRight]:
			if get_cell(i - 1, dj).get_water_flag(c):
				return false
	return true


func play_water_sound() -> void:
	AudioManager.play_sfx("splash" + str(randi()%4 + 1))


func generic_error() -> void:
	for i in rows:
		for j in columns:
			highlight_error(i, j, E.Waters.Single, false)
	AudioManager.play_sfx("error")


func highlight_error(i: int, j: int, which: E.Waters, play_sfx := true) -> void:
	mouse_hold_status = E.MouseDragState.None
	var cell = get_cell(i, j)
	cell.play_error(which)
	if play_sfx:
		AudioManager.play_sfx("error")
	emit_signal("mistake_made")


func enable_wall_editor():
	for corner in CellCornerGrid.get_children():
		corner.enable()


func disable_wall_editor():
	for corner in CellCornerGrid.get_children():
		corner.disable()


func cell_corners_error(i1, j1, i2, j2) -> void:
	CellCornerGrid.get_child(i1*(columns+1) + j1).error()
	CellCornerGrid.get_child(i2*(columns+1) + j2).error()


#Implementation assumes you have at least one cell at grid
func get_global_position_by_index(index : Array) -> Vector2:
	var sample_cell = get_cell(0,0)
	var pos = Columns.global_position
	pos.x += index[1]*sample_cell.size.x * scale.x
	pos.y += index[0]*sample_cell.size.y * scale.y
	return pos


func update_drag_preview() -> void:
	if previous_wall_index and mouse_hold_status == E.MouseDragState.Wall:
		DragPreview.default_color = PREVIEW_DRAG_COLORS.adding
		DragPreview.points = [get_global_position_by_index(previous_wall_index), get_global_mouse_position()]
	elif previous_wall_index and mouse_hold_status == E.MouseDragState.RemoveWall:
		DragPreview.default_color = PREVIEW_DRAG_COLORS.removing
		DragPreview.points = [get_global_position_by_index(previous_wall_index), get_global_mouse_position()]
	else:
		DragPreview.points = []


func _on_cell_pressed_main_button(i: int, j: int, which: E.Waters) -> void:
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	match brush_mode:
		E.BrushMode.Water:
			grid_logic.push_empty_undo()
			if cell_data.water_at(corner):
				mouse_hold_status = E.MouseDragState.RemoveWater
				cell_data.remove_content(corner, false)
				play_water_sound()
			else:
				mouse_hold_status = E.MouseDragState.Water
				if cell_data.put_water(corner, false):
					play_water_sound()
				else:
					highlight_error(i, j, which)
		E.BrushMode.Boat:
			grid_logic.push_empty_undo()
			if cell_data.has_boat():
				mouse_hold_status = E.MouseDragState.RemoveBoat
				cell_data.remove_content(E.Corner.BottomLeft, false)
				AudioManager.play_sfx("boat_remove")
			else:
				mouse_hold_status = E.MouseDragState.Boat
				if cell_data.put_boat(false):
					AudioManager.play_sfx("boat_put")
				else:
					highlight_error(i, j, which)
		E.BrushMode.Block:
			grid_logic.push_empty_undo()
			if cell_data.block_at(corner):
				mouse_hold_status = E.MouseDragState.RemoveBlock
				cell_data.remove_content(corner, false)
				AudioManager.play_sfx("block_remove")
			else:
				mouse_hold_status = E.MouseDragState.Block
				if not cell_data.put_block(corner, false):
					highlight_error(i, j, which)
				else:
					AudioManager.play_sfx("block_put")
			get_cell(i, j).update_blocks(cell_data)
	update()


func _on_cell_pressed_second_button(i: int, j: int, which: E.Waters) -> void:
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if cell_data.air_at(corner):
		mouse_hold_status = E.MouseDragState.RemoveAir
		cell_data.remove_content(corner)
		AudioManager.play_sfx("air_remove")
	elif cell_data.has_boat():
		mouse_hold_status = E.MouseDragState.RemoveBoat
		cell_data.remove_content(corner)
		AudioManager.play_sfx("boat_remove")
	elif cell_data.block_at(corner):
		mouse_hold_status = E.MouseDragState.RemoveBlock
		cell_data.remove_content(corner)
		get_cell(i, j).update_blocks(cell_data)
		AudioManager.play_sfx("block_remove")
	else:
		mouse_hold_status = E.MouseDragState.Air
		if cell_data.put_air(corner):
			AudioManager.play_sfx("air_put")
		else:
			highlight_error(i, j, which)
	update()


func _on_cell_mouse_entered(i: int, j: int, which: E.Waters) -> void:
	if mouse_hold_status == E.MouseDragState.None:
		return
	
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if mouse_hold_status == E.MouseDragState.Water and cell_data.nothing_at(corner):
		if cell_data.put_water(corner, false):
			play_water_sound()
		else:
			highlight_error(i, j, which)
	elif mouse_hold_status == E.MouseDragState.Air and cell_data.nothing_at(corner):
		if cell_data.put_air(corner, false):
			AudioManager.play_sfx("air_put")
		else:
			highlight_error(i, j, which)
	elif mouse_hold_status == E.MouseDragState.Boat and cell_data.nothing_at(corner):
		if cell_data.put_boat(false):
			AudioManager.play_sfx("boat_put")
		else:
			highlight_error(i, j, which)
	elif mouse_hold_status == E.MouseDragState.Block and cell_data.nothing_at(corner):
		if cell_data.put_block(corner, false):
			get_cell(i, j).update_blocks(cell_data)
		else:
			highlight_error(i, j, which)
	elif mouse_hold_status == E.MouseDragState.RemoveWater and cell_data.water_at(corner):
		cell_data.remove_content(corner, false)
		play_water_sound()
	elif mouse_hold_status == E.MouseDragState.RemoveAir and cell_data.air_at(corner):
		cell_data.remove_content(corner, false)
		AudioManager.play_sfx("air_remove")
	elif mouse_hold_status == E.MouseDragState.RemoveBoat and cell_data.has_boat():
		cell_data.remove_content(corner, false)
		AudioManager.play_sfx("boat_remove")
	elif mouse_hold_status == E.MouseDragState.RemoveBlock and cell_data.block_at(corner):
		cell_data.remove_content(corner, false)
		get_cell(i, j).update_blocks(cell_data)
	
	update()


func _on_cell_corner_pressed_main_button(i: int, j: int) -> void:
	mouse_hold_status = E.MouseDragState.Wall
	previous_wall_index = [i, j]


func _on_cell_corner_pressed_second_button(i: int, j: int) -> void:
	mouse_hold_status = E.MouseDragState.RemoveWall
	previous_wall_index = [i, j]

func _on_cell_corner_mouse_entered(i: int, j: int) -> void:
	var new_index = [i, j]
	if not previous_wall_index.is_empty():
		if mouse_hold_status == E.MouseDragState.Wall:
			if not grid_logic.put_wall_from_idx(previous_wall_index[0], previous_wall_index[1],\
										 new_index[0], new_index[1], false):
				cell_corners_error(i, j, previous_wall_index[0], previous_wall_index[1])
			update(true, true)
		if mouse_hold_status == E.MouseDragState.RemoveWall:
			if not grid_logic.remove_wall_from_idx(previous_wall_index[0], previous_wall_index[1],\
											new_index[0], new_index[1], false):
				cell_corners_error(i, j, previous_wall_index[0], previous_wall_index[1])
			update(true, true)
	else:
		# First wall should be its own undo part
		grid_logic.push_empty_undo()
	previous_wall_index = new_index


func _add_col():
	if grid_logic.cols() < MAX_GRID_C:
		grid_logic.add_col()
		update()
		emit_signal("updated_size")
	else:
		generic_error()


func _rem_row():
	if grid_logic.rows() > MIN_GRID_R:
		grid_logic.rem_row()
		update()
		emit_signal("updated_size")
	else:
		generic_error()


func _rem_col():
	if grid_logic.cols() > MIN_GRID_C:
		grid_logic.rem_col()
		update()
		emit_signal("updated_size")
	else:
		generic_error()


func _add_row():
	if grid_logic.rows() < MAX_GRID_R:
		grid_logic.add_row()
		update()
		emit_signal("updated_size")
	else:
		generic_error()
