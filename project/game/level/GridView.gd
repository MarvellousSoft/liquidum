class_name GridView
extends Control


signal updated
signal mistake_made
signal updated_size

const STARTUP_MAX_DELAY = 0.1
const MAX_STARTUP_TIME = 2.8
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
@onready var FillerPanelRight = %FillerPanelRight
@onready var FillerPanelBottom = %FillerPanelBottom
@onready var SizePanel = %SizePanel
@onready var GridSizeLabel = %GridSizeLabel
@onready var AnimPlayer = $AnimationPlayer

var disabled = false
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
		child.queue_free()
	for child in CellCornerGrid.get_children():
		CellCornerGrid.remove_child(child)
		child.queue_free()

# If fast_startup, don't do an animation in the beginning
func setup(grid_logic_: GridModel, fast_startup := false) -> void:
	grid_logic = grid_logic_
	editor_mode = grid_logic.editor_mode()
	rows = grid_logic.rows()
	columns = grid_logic.cols()
	for node in [EditColumnSize, EditRowSize]:
		node.visible = editor_mode
	for node in [FillerPanelRight, FillerPanelBottom]:
		node.visible = not editor_mode
	reset()
	for i in rows:
		var new_row = HBoxContainer.new()
		new_row.add_theme_constant_override("separation", 0)
		Columns.add_child(new_row)
		for j in columns:
			var cell_data = grid_logic.get_cell(i, j)
			create_cell(new_row, cell_data, i, j, fast_startup)
	
	GridSizeLabel.text = "%dx%d" % [rows, columns]
	setup_hints(fast_startup)
	setup_cell_corners()
	update()
	if not editor_mode and not fast_startup:
		disable()
		await get_tree().create_timer(get_grid_delay(rows, columns)).timeout
		AnimPlayer.play("startup")
		enable()
	else:
		SizePanel.modulate.a = 1.0

#Assumes grid_logic is already setup
func setup_hints(fast_startup: bool) -> void:
	assert(grid_logic, "Grid Logic not properly set to setup grid hints")
	HintBars.top.setup(grid_logic.col_hints(), editor_mode)
	HintBars.left.setup(grid_logic.row_hints(), editor_mode)
	var delay = get_grid_delay(rows, columns)
	HintBars.left.startup(editor_mode, delay + STARTUP_MAX_DELAY, fast_startup)
	HintBars.top.startup(editor_mode, delay + STARTUP_MAX_DELAY*2, fast_startup)


func setup_cell_corners() -> void:
	await get_tree().process_frame
	for child in CellCornerGrid.get_children():
		CellCornerGrid.remove_child(child)
		child.queue_free()
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
	disabled = false
	for i in rows:
		for j in columns:
			get_cell(i, j).enable()


func disable() -> void:
	disabled = true
	mouse_hold_status = E.MouseDragState.None
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
	var result := SolverModel.new().full_solve(grid_logic, strategies, func(): return false, flush_undo)
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


func get_grid_delay(r : int, c : int) -> float:
	return min(r*c*STARTUP_MAX_DELAY, MAX_STARTUP_TIME)


func get_cell_delay(r : int, c : int) -> float:
	return get_grid_delay(r, c)/float(r*c)


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int, fast_startup : bool) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)

	cell.setup(self, cell_data, n, m, editor_mode, get_cell_delay(rows, columns), fast_startup)
	
	cell.pressed_main_button.connect(_on_cell_pressed_main_button)
	cell.pressed_second_button.connect(_on_cell_pressed_second_button)
	cell.mouse_entered.connect(_on_cell_mouse_entered)
	cell.block_entered.connect(_on_block_mouse_entered)
	
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
				cell.remove_nowater()
				cell.set_boat(false)
				cell.set_water(E.Single, true)
			elif cell_data.nowater_full():
				cell.remove_water()
				cell.set_boat(false)
				cell.set_nowater(E.Single, true)
			elif cell_data.has_boat():
				cell.remove_water()
				cell.remove_nowater()
				cell.set_boat(true)
			elif cell_data.nothing_full():
				cell.remove_water()
				cell.remove_nowater()
				cell.set_boat(false)
			else:
				for corner in E.Corner.values():
					cell.set_water(corner, cell_data.water_at(corner))
					cell.set_nowater(corner, cell_data.nowater_at(corner))
			if fast_update:
				cell.fast_update_waters()


func update_hints() -> void:
	var row_hints := grid_logic.row_hints()
	for i in rows:
		for hint_type in [E.HintContent.Water, E.HintContent.Boat]:
			var hint: Hint = HintBars.left.get_hint(i, hint_type == E.HintContent.Boat)
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
			var hint: Hint = HintBars.top.get_hint(j, hint_type == E.HintContent.Boat)
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


func remove_all_highlights():
	for i in rows:
		for j in columns:
			get_cell(i, j).set_highlight(false)
	HintBars.left.remove_all_highlights()
	HintBars.top.remove_all_highlights()


func highlight_grid(p_i : int, p_j : int) -> void:
	for i in rows:
		for j in columns:
			get_cell(i, j).set_highlight(i == p_i or j == p_j)
	HintBars.left.highlight_hints(p_i)
	HintBars.top.highlight_hints(p_j)


func show_preview(p_i : int, p_j : int, which : E.Waters) -> void:
	remove_all_preview()
	@warning_ignore("incompatible_ternary")
	var corner = which if which != E.Waters.Single else E.Corner.TopLeft
	var affected_cells = grid_logic.get_cell(p_i, p_j).water_would_flood_which(corner)
	for cell_data in affected_cells:
		var cell = get_cell(cell_data.i, cell_data.j)
		cell.set_water_preview(cell_data.loc, true)


func remove_all_preview() -> void:
	for i in rows:
		for j in columns:
			get_cell(i, j).remove_all_water_preview()


func highlight_row(idx):
	for j in columns:
		get_cell(idx, j).set_highlight(true)


func highlight_column(idx):
	for i in rows:
		get_cell(i, idx).set_highlight(true)


func _on_cell_pressed_main_button(i: int, j: int, which: E.Waters) -> void:
	if disabled:
		return
	
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
		E.BrushMode.NoWater:
			grid_logic.push_empty_undo()
			if cell_data.nowater_at(corner):
				mouse_hold_status = E.MouseDragState.RemoveNoWater
				cell_data.remove_content(corner, false)
				AudioManager.play_sfx("nowater_remove")
			else:
				mouse_hold_status = E.MouseDragState.NoWater
				if cell_data.put_nowater(corner, false):
					AudioManager.play_sfx("nowater_put")
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
	if disabled:
		return
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if cell_data.nowater_at(corner):
		mouse_hold_status = E.MouseDragState.RemoveNoWater
		cell_data.remove_content(corner)
		AudioManager.play_sfx("nowater_remove")
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
		if brush_mode == E.BrushMode.NoWater:
			pass #Do unknown stuff here
		else:
			mouse_hold_status = E.MouseDragState.NoWater
			if cell_data.put_nowater(corner):
				AudioManager.play_sfx("nowater_put")
			else:
				highlight_error(i, j, which)
	update()


func _on_cell_mouse_entered(i: int, j: int, which: E.Waters) -> void:
	if disabled:
		return
	
	if Profile.get_option("highlight_grid"):
		highlight_grid(i, j)
	if Profile.get_option("show_grid_preview") and brush_mode == E.BrushMode.Water and mouse_hold_status == E.MouseDragState.None:
		show_preview(i, j, which)
	
	if mouse_hold_status == E.MouseDragState.None:
		return
	
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if mouse_hold_status == E.MouseDragState.Water and cell_data.nothing_at(corner):
		if cell_data.put_water(corner, false):
			play_water_sound()
		else:
			highlight_error(i, j, which)
	elif mouse_hold_status == E.MouseDragState.NoWater and cell_data.nothing_at(corner):
		if cell_data.put_nowater(corner, false):
			AudioManager.play_sfx("nowater_put")
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
	elif mouse_hold_status == E.MouseDragState.RemoveNoWater and cell_data.nowater_at(corner):
		cell_data.remove_content(corner, false)
		AudioManager.play_sfx("nowater_remove")
	elif mouse_hold_status == E.MouseDragState.RemoveBoat and cell_data.has_boat():
		cell_data.remove_content(corner, false)
		AudioManager.play_sfx("boat_remove")
	elif mouse_hold_status == E.MouseDragState.RemoveBlock and cell_data.block_at(corner):
		cell_data.remove_content(corner, false)
		get_cell(i, j).update_blocks(cell_data)
	
	update()


func _on_cell_corner_pressed_main_button(i: int, j: int) -> void:
	if disabled:
		return
	mouse_hold_status = E.MouseDragState.Wall
	previous_wall_index = [i, j]


func _on_cell_corner_pressed_second_button(i: int, j: int) -> void:
	if disabled:
		return
	mouse_hold_status = E.MouseDragState.RemoveWall
	previous_wall_index = [i, j]


func _on_cell_corner_mouse_entered(i: int, j: int) -> void:
	if disabled:
		return
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


func _on_left_grid():
	if Profile.get_option("highlight_grid"):
		remove_all_highlights()
	if Profile.get_option("show_grid_preview"):
		remove_all_preview()


func _on_hint_bar_top_mouse_entered_hint(idx):
	if disabled:
		return
	remove_all_highlights()
	highlight_column(idx)
	HintBars.top.highlight_hints(idx)
	if Profile.get_option("show_grid_preview"):
		remove_all_preview()


func _on_hint_bar_left_mouse_entered_hint(idx):
	if disabled:
		return
	remove_all_highlights()
	highlight_row(idx)
	HintBars.left.highlight_hints(idx)
	if Profile.get_option("show_grid_preview"):
		remove_all_preview()


func _on_block_mouse_entered(row : int, column : int):
	if disabled:
		return
	highlight_grid(row, column)
