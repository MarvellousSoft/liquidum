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
		new_row.add_theme_constant_override("separation", 0)
		Columns.add_child(new_row)
		for j in m:
			var cell_data = grid_logic.get_cell(i, j)
			create_cell(new_row, cell_data, i, j)


func create_cell(new_row : Node, cell_data : GridImpl.CellModel, n : int, m : int) -> Cell:
	var cell = REGULAR_CELL.instantiate()
	new_row.add_child(cell)
	
	var type = E.CellType.Single
	if cell_data.diag_wall_at(E.Diagonal.Inc):
		type = E.CellType.IncDiag
	elif cell_data.diag_wall_at(E.Diagonal.Dec):
		type = E.CellType.DecDiag
	cell.setup(type, n, m)
	
	if cell_data.wall_at(E.Side.Top):
		cell.set_wall(E.Walls.Top)
	if cell_data.wall_at(E.Side.Right):
		cell.set_wall(E.Walls.Right)
	if cell_data.wall_at(E.Side.Bottom):
		cell.set_wall(E.Walls.Bottom)
	if cell_data.wall_at(E.Side.Left):
		cell.set_wall(E.Walls.Left)
	
	cell.pressed.connect(_on_cell_pressed)
	return cell


func get_cell(i: int, j: int) -> Node:
	return Columns.get_child(i).get_child(j)


func string_to_corner(s : String) -> E.Corner:
	match s:
		"s":
			return E.Corner.BottomLeft
		"tl":
			return E.Corner.TopLeft
		"tr":
			return E.Corner.TopRight
		"br":
			return E.Corner.BottomRight
		"bl":
			return E.Corner.BottomLeft
		_:
			push_error("Not a valid corner:" + str(s))
	return E.Corner.BottomLeft


func string_to_water_side(s : String) -> E.Waters:
	match s:
		"s":
			return E.Waters.Single
		"tl":
			return E.Waters.TopLeft
		"tr":
			return E.Waters.TopRight
		"br":
			return E.Waters.BottomRight
		"bl":
			return E.Waters.BottomLeft
		_:
			push_error("Not a valid corner:" + str(s))
	return E.Waters.None


func _on_cell_pressed(i : int, j : int, which : String) -> void:
	var cell_data = grid_logic.get_cell(i, j)
	var cell = get_cell (i, j)
	var corner = string_to_corner(which)
	if cell_data.water_at(corner):
		cell_data.remove_water_or_air(corner)
		cell.set_water(string_to_water_side(which), false)
	else:
		cell_data.put_water(corner)
		cell.set_water(string_to_water_side(which), true)
	
