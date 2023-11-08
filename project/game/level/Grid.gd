extends Control

const REGULAR_CELL = preload("res://game/level/cells/RegularCell.tscn")

@onready var Columns = $CenterContainer/Columns

var grid_logic : GridImpl
var rows : int
var columns : int

func setup(level : String) -> void:
	grid_logic = GridImpl.from_str(level)
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


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)
	
	var type := E.CellType.Single
	for diag in E.Diagonal.values():
		if cell_data.diag_wall_at(diag):
			type = diag
	cell.setup(type, n, m)
	
	for side in E.Side.values():
		if cell_data.wall_at(side):
			cell.set_wall(side)
	
	cell.pressed.connect(_on_cell_pressed)
	return cell


func update_visuals() -> void:
	for i in rows:
		for j in columns:
			var cell_data := grid_logic.get_cell(i, j)
			var cell := get_cell(i, j) as Cell
			if cell_data.water_full():
				cell.set_water(E.Single, true)
			elif cell_data.nothing_full():
				cell.remove_water()
			else:
				for corner in E.Corner.values():
					cell.set_water(corner, cell_data.water_at(corner))


func get_cell(i: int, j: int) -> Node:
	return Columns.get_child(i).get_child(j)


func _on_cell_pressed(i: int, j: int, which: E.Waters) -> void:
	assert(which != E.Waters.None)
	var cell_data := grid_logic.get_cell(i, j)
	var corner = E.BottomLeft if which == E.Single else which
	if cell_data.water_at(corner):
		cell_data.remove_water_or_air(corner)
	else:
		cell_data.put_water(corner)
	update_visuals()

