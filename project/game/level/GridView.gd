class_name GridView
extends Control

signal updated

const REGULAR_CELL = preload("res://game/level/cells/RegularCell.tscn")

@onready var GridCont = $CenterContainer/GridContainer
@onready var Columns = $CenterContainer/GridContainer/Columns
@onready var HintBars = {
	"top": $CenterContainer/GridContainer/HintBarTop,
	"left": $CenterContainer/GridContainer/HintBarLeft,
}
@onready var editor_mode := false

var brush_mode : E.BrushMode = E.BrushMode.Water
var grid_logic : GridModel
var rows : int
var columns : int
var mouse_hold_status : E.MouseDragState = E.MouseDragState.None

func _input(event):
	if event is InputEventMouseButton:
		if not event.pressed:
			mouse_hold_status = E.MouseDragState.None
	elif grid_logic and event.is_action_pressed("undo"):
		grid_logic.undo()
		update()
	elif grid_logic and event.is_action_pressed("redo"):
		grid_logic.redo()
		update()
		

func setup(level : String, with_solution := true, clear_solution := true) -> void:
	grid_logic = GridImpl.from_str(level, with_solution, clear_solution)
	rows = grid_logic.rows()
	columns = grid_logic.cols() 
	for child in Columns.get_children():
		Columns.remove_child(child)
	for i in rows:
		var new_row = HBoxContainer.new()
		new_row.add_theme_constant_override("separation", 0)
		Columns.add_child(new_row)
		for j in columns:
			var cell_data = grid_logic.get_cell(i, j)
			create_cell(new_row, cell_data, i, j)
	setup_hints()
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

#Assumes grid_logic is already setup
func setup_hints():
	assert(grid_logic, "Grid Logic not properly set to setup grid hints")
	HintBars.top.setup(grid_logic.hint_all_cols())
	HintBars.left.setup(grid_logic.hint_all_rows())


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)
	
	var type := E.CellType.Single
	for diag in E.Diagonal.values():
		if cell_data.wall_at(diag):
			type = diag
	cell.setup(self, type, n, m)
	
	for side in E.Side.values():
		if cell_data.wall_at(side):
			cell.set_wall(side)
	if cell_data.block_full():
		cell.set_block(E.Single)
	else:
		for corner in E.Corner.values():
			if cell_data.block_at(corner):
				cell.set_block(corner)
	
	cell.pressed_main_button.connect(_on_cell_pressed_main_button)
	cell.pressed_second_button.connect(_on_cell_pressed_second_button)
	cell.mouse_entered.connect(_on_cell_mouse_entered)
	
	return cell


func update(do_emit_signal := true) -> void:
	update_visuals()
	update_hints()
	if do_emit_signal:
		updated.emit()


func update_visuals() -> void:
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


func update_hints() -> void:
	for i in rows:
		var hint = HintBars.left.get_hint(i)
		if grid_logic.is_row_hint_wrong(i):
			hint.set_error()
		elif grid_logic.is_row_hint_satisfied(i):
			hint.set_satisfied()
		else:
			hint.set_normal()
	for j in columns:
		var hint = HintBars.top.get_hint(j)
		if grid_logic.is_col_hint_wrong(j):
			hint.set_error()
		elif grid_logic.is_col_hint_satisfied(j):
			hint.set_satisfied()
		else:
			hint.set_normal()


func get_cell(i: int, j: int) -> Node:
	return Columns.get_child(i).get_child(j)


func can_increase_water(i : int, j : int, corner : E.Waters):
	match corner:
		E.Waters.Single, E.Waters.BottomLeft, E.Waters.BottomRight:
			if grid_logic.wall_at(i, j, E.Side.Bottom):
				return true
			#It can't be the lowest cell since it doesn't have bottom-wall
			var lower_cell = get_cell(i + 1, j)
			for which in [E.Waters.Single, E.Waters.TopLeft, E.Waters.TopRight]:
				if lower_cell.get_corner_water_level(which) >= 1.0:
					return true
			return false
		E.Waters.TopLeft:
			if grid_logic.wall_at(i, j, E.Side.Left):
				return true
			#It can't be the leftmost cell since it doesn't have left-wall
			var left_cell = get_cell(i, j - 1)
			var type = left_cell.get_type()
			match type:
				E.CellType.DecDiag:
					return true
				E.CellType.IncDiag:
					return can_increase_water(i, j - 1, E.Waters.BottomRight)
				E.CellType.Single:
					return can_increase_water(i, j - 1, E.Waters.Single)
				_:
					push_error("Not a valid type for cell:" + str(type))
		E.Waters.TopRight:
			if grid_logic.wall_at(i, j, E.Side.Right):
				return true
			#It can't be the rightmost cell since it doesn't have right-wall
			var right_cell = get_cell(i, j + 1)
			var type = right_cell.get_type()
			match type:
				E.CellType.IncDiag:
					return true
				E.CellType.DecDiag:
					return can_increase_water(i, j + 1, E.Waters.BottomLeft)
				E.CellType.Single:
					return can_increase_water(i, j + 1, E.Waters.Single)
				_:
					push_error("Not a valid type for cell:" + str(type))


func can_decrease_water(i : int, j : int, corner : E.Waters):
	match corner:
		E.Waters.Single, E.Waters.TopLeft, E.Waters.TopRight:
			if grid_logic.wall_at(i, j, E.Side.Top):
				return true
			#It can't be the uppermost cell since it doesn't have top-wall
			var upper_cell = get_cell(i - 1, j)
			for which in [E.Waters.Single, E.Waters.BottomLeft, E.Waters.BottomRight]:
				if upper_cell.get_corner_water_level(which) > 0.0:
					return false
			return true
		E.Waters.BottomLeft:
			if grid_logic.wall_at(i, j, E.Side.Left):
				return true
			#It can't be the leftmost cell since it doesn't have left-wall
			var left_cell = get_cell(i, j - 1)
			var type = left_cell.get_type()
			match type:
				E.CellType.IncDiag:
					return true
				E.CellType.DecDiag:
					return can_decrease_water(i, j - 1, E.Waters.TopRight)
				E.CellType.Single:
					return can_decrease_water(i, j - 1, E.Waters.Single)
				_:
					push_error("Not a valid type for cell:" + str(type))
		E.Waters.BottomRight:
			if grid_logic.wall_at(i, j, E.Side.Right):
				return true
			#It can't be the rightmost cell since it doesn't have right-wall
			var right_cell = get_cell(i, j + 1)
			var type = right_cell.get_type()
			match type:
				E.CellType.DecDiag:
					return true
				E.CellType.IncDiag:
					return can_decrease_water(i, j + 1, E.Waters.TopLeft)
				E.CellType.Single:
					return can_decrease_water(i, j + 1, E.Waters.Single)
				_:
					push_error("Not a valid type for cell:" + str(type))


func is_at_surface(i: int, j: int, corner: E.Waters) -> bool:
	match corner:
		E.Waters.Single, E.Waters.TopLeft, E.Waters.TopRight:
			if grid_logic.wall_at(i, j, E.Side.Top):
				return true
			var upper_cell = get_cell(i - 1, j)
			for which in [E.Waters.Single, E.Waters.BottomLeft, E.Waters.BottomRight]:
				if upper_cell.get_water_flag(which):
					return false
			return true
		E.Waters.BottomLeft:
			if grid_logic.wall_at(i, j, E.Side.Left):
				return true
			#It can't be the leftmost cell since it doesn't have left-wall
			var left_cell = get_cell(i, j - 1)
			var type = left_cell.get_type()
			match type:
				E.CellType.IncDiag:
					return true
				E.CellType.DecDiag:
					return is_at_surface(i, j - 1, E.Waters.TopRight)
				E.CellType.Single:
					return is_at_surface(i, j - 1, E.Waters.Single)
				_:
					push_error("Not a valid type for cell:" + str(type))
					return false
		E.Waters.BottomRight:
			if grid_logic.wall_at(i, j, E.Side.Right):
				return true
			#It can't be the rightmost cell since it doesn't have right-wall
			var right_cell = get_cell(i, j + 1)
			var type = right_cell.get_type()
			match type:
				E.CellType.DecDiag:
					return true
				E.CellType.IncDiag:
					return is_at_surface(i, j + 1, E.Waters.TopLeft)
				E.CellType.Single:
					return is_at_surface(i, j + 1, E.Waters.Single)
				_:
					push_error("Not a valid type for cell:" + str(type))
					return false
		_:
			push_error("Not a valid corner for cell:" + str(corner))
			return false


func highlight_error(i: int, j: int, which: E.Waters) -> void:
	pass


func _on_cell_pressed_main_button(i: int, j: int, which: E.Waters) -> void:
	assert(which != E.Waters.None)
	
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if cell_data.water_at(corner):
		match brush_mode:
			E.BrushMode.Water:
				mouse_hold_status = E.MouseDragState.RemoveWater
				cell_data.remove_content(corner)
			E.BrushMode.Boat:
				mouse_hold_status = E.MouseDragState.Boat
				highlight_error(i, j, which)
	else:
		match brush_mode:
			E.BrushMode.Water:
				mouse_hold_status = E.MouseDragState.Water
				cell_data.put_water(corner)
			E.BrushMode.Boat:
				if cell_data.has_boat():
					mouse_hold_status = E.MouseDragState.RemoveBoat
					cell_data.remove_content(E.Corner.BottomLeft)
				else:
					mouse_hold_status = E.MouseDragState.Boat
					if which == E.Single:
						cell_data.put_boat()
					else:
						highlight_error(i, j, which)
	update()


func _on_cell_pressed_second_button(i: int, j: int, which: E.Waters) -> void:
	assert(which != E.Waters.None)
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if cell_data.air_at(corner):
		mouse_hold_status = E.MouseDragState.RemoveAir
		cell_data.remove_content(corner)
	elif cell_data.has_boat():
		mouse_hold_status = E.MouseDragState.RemoveBoat
		cell_data.remove_content(corner)
	else:
		mouse_hold_status = E.MouseDragState.Air
		cell_data.put_air(corner)
	update()


func _on_cell_mouse_entered(i: int, j: int, which: E.Waters) -> void:
	if mouse_hold_status == E.MouseDragState.None:
		return
	
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.Corner.BottomLeft if which == E.Single else (which as E.Corner)
	if mouse_hold_status == E.MouseDragState.Water and cell_data.nothing_at(corner):
		cell_data.put_water(corner, false)
	elif mouse_hold_status == E.MouseDragState.Air and cell_data.nothing_at(corner):
		cell_data.put_air(corner, false)
	elif mouse_hold_status == E.MouseDragState.Boat and cell_data.nothing_at(corner):
		cell_data.put_boat(false)
	elif mouse_hold_status == E.MouseDragState.RemoveWater and cell_data.water_at(corner):
		cell_data.remove_content(corner, false)
	elif mouse_hold_status == E.MouseDragState.RemoveAir and cell_data.air_at(corner):
		cell_data.remove_content(corner, false)
	elif mouse_hold_status == E.MouseDragState.RemoveBoat and cell_data.has_boat():
		cell_data.remove_content(corner, false)
	
	update()
