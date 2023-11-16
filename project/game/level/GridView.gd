class_name GridView
extends Control

const STARTUP_DELAY = 0.1

signal updated
signal mistake_made

const REGULAR_CELL = preload("res://game/level/cells/RegularCell.tscn")
const PREVIEW_DRAG_COLORS = {
	"adding": Color("#61fc89df"),
	"removing": Color("#ff6464df"),
}

@export var editor_mode := false

@onready var GridCont = $CenterContainer/GridContainer
@onready var Columns = $CenterContainer/GridContainer/Columns
@onready var HintBars = {
	"top": $CenterContainer/GridContainer/HintBarTop,
	"left": $CenterContainer/GridContainer/HintBarLeft,
}
@onready var DragPreview = $DragPreviewCanvas/DragPreviewLine

var brush_mode : E.BrushMode = E.BrushMode.Water
var grid_logic : GridModel
var rows : int
var columns : int
var mouse_hold_status : E.MouseDragState = E.MouseDragState.None
var previous_wall_index := []

func _ready():
	reset()


func _process(_dt):
	update_drag_preview()


func _input(event):
	if event is InputEventMouseButton:
		if not event.pressed:
			mouse_hold_status = E.MouseDragState.None
			previous_wall_index = []
	elif grid_logic and event.is_action_pressed("undo"):
		grid_logic.undo()
		update()
	elif grid_logic and event.is_action_pressed("redo"):
		grid_logic.redo()
		update()


func reset() -> void:
	for child in Columns.get_children():
		Columns.remove_child(child)


func setup(level : String, load_mode := GridModel.LoadMode.Solution) -> void:
	grid_logic = GridImpl.from_str(level, load_mode)
	rows = grid_logic.rows()
	columns = grid_logic.cols() 
	reset()
	for i in rows:
		var new_row = HBoxContainer.new()
		new_row.add_theme_constant_override("separation", 0)
		Columns.add_child(new_row)
		for j in columns:
			var cell_data = grid_logic.get_cell(i, j)
			create_cell(new_row, cell_data, i, j)
	setup_hints(rows, columns)
	update()


func get_grid_size() -> Vector2:
	return GridCont.size


func auto_solve(flush_undo := true, do_emit_signal := true) -> void:
	SolverModel.new().apply_strategies(grid_logic, flush_undo)
	update(do_emit_signal)

func full_solve(flush_undo := true, do_emit_signal := true) -> SolverModel.SolveResult:
	var result := SolverModel.new().full_solve(grid_logic, flush_undo)
	update(do_emit_signal)
	return result


func set_brush_mode(mode : E.BrushMode) -> void:
	brush_mode = mode
	if mode == E.BrushMode.Wall:
		enable_wall_editor()
	else:
		disable_wall_editor()

#Assumes grid_logic is already setup
func setup_hints(i : int, j : int):
	assert(grid_logic, "Grid Logic not properly set to setup grid hints")
	HintBars.top.setup(grid_logic.col_hints())
	HintBars.left.setup(grid_logic.row_hints())
	var delay = STARTUP_DELAY * (i + 1) * j
	HintBars.left.startup(delay + STARTUP_DELAY)
	HintBars.top.startup(delay + STARTUP_DELAY*2)
	
func get_expected_waters() -> float:
	return grid_logic.get_expected_waters()


func get_expected_boats() -> float:
	return grid_logic.get_expected_boats()

#Assumes the expected waters is >= 0
func get_missing_waters() -> float:
	return grid_logic.get_expected_waters() - grid_logic.count_waters()


func get_missing_boats() -> int:
	return grid_logic.get_expected_boats() - grid_logic.count_boats()


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)

	cell.setup(self, cell_data, n, m)
	
	cell.pressed_main_button.connect(_on_cell_pressed_main_button)
	cell.pressed_second_button.connect(_on_cell_pressed_second_button)
	cell.mouse_entered.connect(_on_cell_mouse_entered)
	cell.pressed_main_corner_button.connect(_on_cell_pressed_main_corner_button)
	cell.pressed_second_corner_button.connect(_on_cell_pressed_second_corner_button)
	cell.mouse_entered_corner_button.connect(_on_cell_mouse_entered_corner_button)
	
	return cell


func update(do_emit_signal := true, fast_update := false) -> void:
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
	for i in rows:
		for hint_type in [E.HintContent.Water, E.HintContent.Boat]:
			var hint = HintBars.left.get_hint(i, hint_type == E.HintContent.Boat)
			if hint:
				match grid_logic.get_row_hint_status(i, hint_type):
					E.HintStatus.Normal:
						hint.set_normal()
					E.HintStatus.Satisfied:
						hint.set_satisfied()
					E.HintStatus.Wrong:
						hint.set_error()
	for j in columns:
		for hint_type in [E.HintContent.Water, E.HintContent.Boat]:
			var hint = HintBars.top.get_hint(j, hint_type == E.HintContent.Boat)
			if hint:
				match grid_logic.get_col_hint_status(j, hint_type):
					E.HintStatus.Normal:
						hint.set_normal()
					E.HintStatus.Satisfied:
						hint.set_satisfied()
					E.HintStatus.Wrong:
						hint.set_error()


func get_cell(i: int, j: int) -> Node:
	return Columns.get_child(i).get_child(j)

func _connections_down(i: int, j: int, corner: E.Waters) -> Array[int]:
	var conns: Array[int] = []
	var single := (corner == E.Waters.Single)
	# Check down
	if !grid_logic.wall_at(i, j, E.Side.Bottom) and (single or !E.corner_is_top(corner as E.Corner)):
		conns.append(j)
	if !grid_logic.wall_at(i, j, E.Side.Right) and (single or !E.corner_is_left(corner as E.Corner)):
		var c := grid_logic.get_cell(i, j + 1)
		if !c.wall_at(E.Walls.IncDiag) and !c.wall_at(E.Walls.Bottom):
			conns.append(j + 1)
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
	if !grid_logic.wall_at(i, j, E.Side.Right) and (single or !E.corner_is_left(corner as E.Corner)):
		var c := grid_logic.get_cell(i, j + 1)
		if !c.wall_at(E.Walls.DecDiag) and !c.wall_at(E.Walls.Top):
			conns.append(j + 1)
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


func highlight_error(i: int, j: int, which: E.Waters) -> void:
	var cell = get_cell(i, j)
	cell.play_error(which)
	AudioManager.play_sfx("error")
	emit_signal("mistake_made")


func enable_wall_editor():
	for i in rows:
		for j in columns:
			get_cell(i, j).enable_wall_editor()


func disable_wall_editor():
	for i in rows:
		for j in columns:
			get_cell(i, j).disable_wall_editor()


func get_wall_index(i : int, j : int, which : E.Corner) -> Array:
	match which:
		E.Corner.TopLeft:
			return [i, j]
		E.Corner.TopRight:
			return [i, j + 1]
		E.Corner.BottomRight:
			return [i + 1, j + 1]
		E.Corner.BottomLeft:
			return [i + 1, j]
		_:
			push_error("Not a valid corner: " + str(which))
			return []

#Implementation assumes you have at least one cell at grid
func get_global_position_by_index(index : Array) -> Vector2:
	var sample_cell = get_cell(0,0)
	var pos = Columns.global_position
	pos.x += index[1]*sample_cell.size.x
	pos.y += index[0]*sample_cell.size.y
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
	if cell_data.water_at(corner):
		match brush_mode:
			E.BrushMode.Water:
				mouse_hold_status = E.MouseDragState.RemoveWater
				cell_data.remove_content(corner)
				play_water_sound()
			E.BrushMode.Boat:
				mouse_hold_status = E.MouseDragState.Boat
				highlight_error(i, j, which)
	else:
		match brush_mode:
			E.BrushMode.Water:
				mouse_hold_status = E.MouseDragState.Water
				if cell_data.put_water(corner):
					play_water_sound()
				else:
					highlight_error(i, j, which)
			E.BrushMode.Boat:
				if cell_data.has_boat():
					mouse_hold_status = E.MouseDragState.RemoveBoat
					cell_data.remove_content(E.Corner.BottomLeft)
					AudioManager.play_sfx("boat_remove")
				else:
					mouse_hold_status = E.MouseDragState.Boat
					if which == E.Single:
						if cell_data.put_boat():
							AudioManager.play_sfx("boat_put")
						else:
							highlight_error(i, j, which)
					else:
						highlight_error(i, j, which)
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
	elif mouse_hold_status == E.MouseDragState.RemoveWater and cell_data.water_at(corner):
		cell_data.remove_content(corner, false)
		play_water_sound()
	elif mouse_hold_status == E.MouseDragState.RemoveAir and cell_data.air_at(corner):
		cell_data.remove_content(corner, false)
		AudioManager.play_sfx("air_remove")
	elif mouse_hold_status == E.MouseDragState.RemoveBoat and cell_data.has_boat():
		cell_data.remove_content(corner, false)
		AudioManager.play_sfx("boat_remove")
	
	update()

func _on_cell_pressed_main_corner_button(i: int, j: int, which: E.Corner) -> void:
	mouse_hold_status = E.MouseDragState.Wall
	previous_wall_index = get_wall_index(i, j, which)


func _on_cell_pressed_second_corner_button(i: int, j: int, which: E.Corner) -> void:
	mouse_hold_status = E.MouseDragState.RemoveWall
	previous_wall_index = get_wall_index(i, j, which)

func _on_cell_mouse_entered_corner_button(i: int, j: int, which: E.Corner) -> void:
	var new_index = get_wall_index(i, j, which)
	if not previous_wall_index.is_empty():
		if mouse_hold_status == E.MouseDragState.Wall:
			grid_logic.put_wall_from_idx(previous_wall_index[0], previous_wall_index[1],\
										 new_index[0], new_index[1], false)
			update_walls()
			update(true, true)
		if mouse_hold_status == E.MouseDragState.RemoveWall:
			grid_logic.remove_wall_from_idx(previous_wall_index[0], previous_wall_index[1],\
											new_index[0], new_index[1], false)
			update_walls()
			update(true, true)
	else:
		# First wall should be its own undo part
		grid_logic.push_empty_undo()
	previous_wall_index = new_index
