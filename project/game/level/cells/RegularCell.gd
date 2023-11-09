extends Cell

const DIAGONAL_BUTTON_MASK = preload("res://assets/images/ui/diagonal_button_mask.png")
const SURFACE_THRESHOLD = 0.7

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
var water_flags = {
	E.Waters.Single: false,
	E.Waters.TopLeft: false,
	E.Waters.TopRight: false,
	E.Waters.BottomLeft: false,
	E.Waters.BottomRight: false,
}


func _ready():
	for water in Waters.values():
		water.material = water.material.duplicate()


func _process(dt):
	for corner in E.Waters.values():
		if corner != E.Waters.None:
			if water_flags[corner]:
				increase_water_level(Waters[corner], dt)
			else:
				decrease_water_level(Waters[corner], dt)


func setup(type : E.CellType, i : int, j : int) -> void:
	row = i
	column = j
	for water in Waters.values():
		water.show()
		set_water_level(water, 0.0)
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
	for flag in water_flags.keys():
		water_flags[flag] = false


func set_water(water : E.Waters, value: bool) -> void:
	match water:
		E.Waters.None:
			remove_water()
		_:
			water_flags[water] = value


func remove_air():
	for air in Airs.values():
		air.hide()


func set_air(air : E.Waters, value: bool) -> void:
	match air:
		E.Waters.None:
			remove_air()
		_:
			Airs[air].visible = value


func set_water_level(water, value) -> void:
	water.material.set_shader_parameter("level", value)


func increase_water_level(water, dt) -> void:
	var level = water.material.get_shader_parameter("level")
	level = min(level + dt, 1.0)
	water.material.set_shader_parameter("level", level)


func decrease_water_level(water, dt) -> void:
	var level = water.material.get_shader_parameter("level")
	level = max(level - dt, 0.0)
	water.material.set_shader_parameter("level", level)


func _on_button_gui_input(event, which : E.Waters) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				pressed_water.emit(row, column, which)
			MOUSE_BUTTON_RIGHT:
				pressed_air.emit(row, column, which)


func _on_button_mouse_entered(which : E.Waters):
	mouse_entered.emit(row, column, which)
