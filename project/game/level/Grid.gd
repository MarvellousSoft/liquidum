extends Control

const GRID_IMPL = preload("res://game/level/grid/GridImpl.gd")
const REGULAR_CELL = preload("res://game/level/cells/RegularCell.tscn")

@onready var Columns = $CenterContainer/Columns

var grid_logic : GridImpl

func setup(n : int, m : int, level : String) -> void: 
	grid_logic = GRID_IMPL.new(n, m)
	grid_logic.load_from_str(level)
	for child in Columns.get_children():
		Columns.remove_child(child)
	for i in n:
		var new_row = HBoxContainer.new()
		Columns.add_child(new_row)
		for j in m:
			var cell_data = grid_logic.get_cell(i, j)
			create_cell(new_row, cell_data, i, j)


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)
	
	var type = Cell.TYPES.SINGLE
	if cell_data.diag_wall_at(GridModel.Diagonal.Inc):
		type = Cell.TYPES.INC_DIAG
	elif cell_data.diag_wall_at(GridModel.Diagonal.Dec):
		type = Cell.TYPES.DEC_DIAG
	cell.setup(type, n, m)
	
	if cell_data.wall_at(GridModel.Side.Top):
		cell.set_wall(Cell.WALLS.TOP)
	if cell_data.wall_at(GridModel.Side.Right):
		cell.set_wall(Cell.WALLS.RIGHT)
	if cell_data.wall_at(GridModel.Side.Bottom):
		cell.set_wall(Cell.WALLS.BOTTOM)
	if cell_data.wall_at(GridModel.Side.Left):
		cell.set_wall(Cell.WALLS.LEFT)
	
	cell.pressed.connect(_on_cell_pressed)
	return cell


func _on_cell_pressed(i, j, which):
	printt(i,j,which)
	
