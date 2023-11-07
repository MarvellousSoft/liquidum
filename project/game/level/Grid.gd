extends Control

const GRID_IMPL = preload("res://game/level/grid/GridImpl.gd")
const REGULAR_CELL = preload("res://game/level/cells/RegularCell.tscn")

@onready var Columns = $CenterContainer/Columns

var grid_logic : GridImpl

func setup(n : int, m : int) -> void: 
	grid_logic = GRID_IMPL.new(n, m)
	for child in Columns.get_children():
		Columns.remove_child(child)
	for i in n:
		var new_row = HBoxContainer.new()
		Columns.add_child(new_row)
		for j in m:
			var type = [Cell.TYPES.SINGLE, Cell.TYPES.INC_DIAG, Cell.TYPES.DEC_DIAG].pick_random()
			create_cell(new_row, type, i, j)


func create_cell(new_row : Node, type : Cell.TYPES, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)
	cell.setup(type, n, m)
	cell.pressed.connect(_on_cell_pressed)
	return cell


func _on_cell_pressed(i, j, which):
	printt(i,j,which)
	
