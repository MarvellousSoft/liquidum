extends Cell

const DIAGONAL_BUTTON_MASK = preload("res://assets/images/ui/diagonal_button_mask.png")

signal pressed_water(i: int, j: int, which: E.Waters)
signal pressed_air(i: int, j: int, which: E.Waters)

@onready var Waters = {
	E.Waters.Single: $Waters/Single,
	E.Waters.TopLeft: $Waters/TopLeft,
	E.Waters.TopRight: $Waters/TopRight,
	E.Waters.BottomLeft: $Waters/BottomLeft,
	E.Waters.BottomRight: $Waters/BottomRight,
}
@onready var Airs = {
	E.Waters.Single: $Airs/Single,
	E.Waters.TopLeft: $Airs/TopLeft,
	E.Waters.TopRight: $Airs/TopRight,
	E.Waters.BottomLeft: $Airs/BottomLeft,
	E.Waters.BottomRight: $Airs/BottomRight,
}
@onready var Buttons = {
	E.Single: $Buttons/Single,
	E.TopLeft: $Buttons/TopLeft,
	E.TopRight: $Buttons/TopRight,
	E.BottomLeft: $Buttons/BottomLeft,
	E.BottomRight: $Buttons/BottomRight,
}
@onready var Hints = {
	E.Walls.Top: $Hints/Top,
	E.Walls.Left:$Hints/Left,
	E.Walls.DecDiag: $Hints/Dec,
	E.Walls.IncDiag: $Hints/Inc,
}
@onready var Walls = {
	E.Walls.Top: $Walls/Top,
	E.Walls.Right: $Walls/Right,
	E.Walls.Bottom: $Walls/Bottom,
	E.Walls.Left:$Walls/Left,
	E.Walls.DecDiag: $Walls/Dec,
	E.Walls.IncDiag: $Walls/Inc,
}

var row : int
var column : int


func setup(type : E.CellType, i : int, j : int) -> void:
	row = i
	column = j
	for water in Waters.values():
		water.hide()
	for air in Airs.values():
		air.hide()
	for buttons in Buttons.values():
		buttons.hide()
	for wall in Walls.values():
		wall.hide()
	match type:
		E.CellType.Single:
			Buttons[E.Single].show()
		E.CellType.IncDiag:
			Buttons[E.TopLeft].show()
			Buttons[E.BottomRight].show()
			set_wall(E.Walls.IncDiag)
		E.CellType.DecDiag:
			Buttons[E.TopRight].show()
			Buttons[E.BottomLeft].show()
			set_wall(E.Walls.DecDiag)
		_:
			push_error("Not a valid type of cell:" + str(type))


func set_wall(wall : E.Walls) -> void:
	Walls[wall].show()
	if Hints.has(wall):
		Hints[wall].hide()

func remove_water():
	for water in Waters.values():
		water.hide()


func set_water(water : E.Waters, value: bool) -> void:
	match water:
		E.Waters.None:
			remove_water()
		_:
			Waters[water].visible = value


func remove_air():
	for air in Airs.values():
		air.hide()


func set_air(air : E.Waters, value: bool) -> void:
	match air:
		E.Waters.None:
			remove_air()
		_:
			Airs[air].visible = value


func _on_button_gui_input(event, which : E.Waters) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				pressed_water.emit(row, column, which)
			MOUSE_BUTTON_RIGHT:
				pressed_air.emit(row, column, which)
