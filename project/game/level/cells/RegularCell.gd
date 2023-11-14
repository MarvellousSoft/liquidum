extends Cell

const DIAGONAL_BUTTON_MASK = preload("res://assets/images/ui/cell/diagonal_button_mask.png")
const SURFACE_THRESHOLD = 0.7
const STARTUP_DELAY = 0.1
const BOAT_ALPHA_SPEED = 1.0
const WATER_SPEED_RATIO = 7.0
const MIN_BOAT_ANIM_SPEED = .7
const MAX_BOAT_ANIM_SPEED = .9
const EPS = 0.1

signal pressed_main_button(i: int, j: int, which: E.Waters)
signal pressed_second_button(i: int, j: int, which: E.Waters)
signal pressed_main_corner_button(i: int, j: int, which: E.Waters)
signal pressed_second_corner_button(i: int, j: int, which: E.Waters)
signal mouse_entered_corner_button(i: int, j: int, which: E.Waters)

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
@onready var Blocks = {
	E.Waters.Single: $Blocks/Single,
	E.Waters.TopLeft: $Blocks/TopLeft,
	E.Waters.TopRight: $Blocks/TopRight,
	E.Waters.BottomLeft: $Blocks/BottomLeft,
	E.Waters.BottomRight: $Blocks/BottomRight,
}
@onready var Boat = $Boat
@onready var Errors = {
	E.Waters.Single: $Errors/Single,
	E.Waters.TopLeft: $Errors/TopLeft,
	E.Waters.TopRight: $Errors/TopRight,
	E.Waters.BottomLeft: $Errors/BottomLeft,
	E.Waters.BottomRight: $Errors/BottomRight,
}
@onready var CellCorners = $CellCorners 
@onready var BoatAnim = $Boat/AnimationPlayer
@onready var AnimPlayer = $AnimationPlayer

var row : int
var column : int
var type : E.CellType
var grid
var water_flags = {
	E.Waters.Single: false,
	E.Waters.TopLeft: false,
	E.Waters.TopRight: false,
	E.Waters.BottomLeft: false,
	E.Waters.BottomRight: false,
}
var boat_flag := false
var wall_editor_active := false


func _ready():
	for water in Waters.values():
		water.material = water.material.duplicate()
	BoatAnim.seek(randf_range(0.0, BoatAnim.current_animation_length), true)
	BoatAnim.speed_scale = randf_range(MIN_BOAT_ANIM_SPEED, MAX_BOAT_ANIM_SPEED)


func _process(dt):
	if grid:
		for corner in E.Waters.values():
			if corner != E.Waters.None:
				if water_flags[corner]:
					increase_water_level(corner, dt)
				else:
					decrease_water_level(corner, dt)
				if boat_flag:
					Boat.modulate.a = min(Boat.modulate.a + BOAT_ALPHA_SPEED*dt, 1.0)
				else:
					Boat.modulate.a = max(Boat.modulate.a - BOAT_ALPHA_SPEED*dt, 0.0)


func setup(grid_ref : Node, new_type : E.CellType, i : int, j : int) -> void:
	grid = grid_ref
	row = i
	column = j
	disable_wall_editor()
	for water in Waters.values():
		water.show()
		set_water_level(water, 0.0)
	for air in Airs.values():
		air.hide()
	for buttons in Buttons.values():
		buttons.hide()
	for wall in Walls.values():
		wall.hide()
	for block in Blocks.values():
		block.hide()
	for error in Errors.values():
		error.modulate.a = 0.0
	Boat.modulate.a = 0.0
	type = new_type
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
	
	await get_tree().create_timer((i+1)*j*STARTUP_DELAY).timeout
	
	AnimPlayer.play("startup")


func play_error(which : E.Waters) -> void:
	Errors[which].get_node("AnimationPlayer").play("error")


func get_type() -> E.CellType:
	return type


func set_wall(wall : E.Walls) -> void:
	Walls[wall].show()
	if Hints.has(wall):
		Hints[wall].hide()


func set_block(block : E.Waters) -> void:
	Blocks[block].show()
	Buttons[block].hide()


func set_boat(value) -> void:
	boat_flag = value


func remove_water() -> void:
	for flag in water_flags.keys():
		water_flags[flag] = false


func set_water(water : E.Waters, value: bool) -> void:
	match water:
		E.Waters.None:
			remove_water()
		_:
			set_boat(false)
			water_flags[water] = value


func remove_air() -> void:
	for air in Airs.values():
		air.hide()


func set_air(air : E.Waters, value: bool) -> void:
	match air:
		E.Waters.None:
			remove_air()
		_:
			Airs[air].visible = value


func get_water_flag(corner : E.Waters) -> bool:
	return water_flags[corner]


func get_corner_water_level(corner : E.Waters) -> float:
	return Waters[corner].material.get_shader_parameter("level")


func set_water_level(water, value) -> void:
	water.material.set_shader_parameter("level", value)


func increase_water_level(corner : E.Waters, dt : float) -> void:
	var water = Waters[corner] as Node
	var level = water.material.get_shader_parameter("level")
	var target = SURFACE_THRESHOLD if grid.is_at_surface(row, column, corner) else 1.0
	if level != target and grid.can_increase_water(row, column, corner):
		var ratio = clamp(WATER_SPEED_RATIO*dt, 0.0, 1.0)
		level = lerp(level, target, ratio)
		if abs(level - target) <= EPS:
			level = target
		water.material.set_shader_parameter("level", level)


func decrease_water_level(corner : E.Waters, dt : float) -> void:
	var water = Waters[corner] as Node
	var level = water.material.get_shader_parameter("level")
	if level > 0 and grid.can_decrease_water(row, column, corner):
		var ratio = clamp(WATER_SPEED_RATIO*dt, 0.0, 1.0)
		level = lerp(level, 0.0, ratio)
		if level < EPS:
			level = 0.0
		water.material.set_shader_parameter("level", level)


func enable_wall_editor() -> void:
	wall_editor_active = true
	CellCorners.show()


func disable_wall_editor() -> void:
	wall_editor_active = false
	CellCorners.hide()


func _on_button_gui_input(event, which : E.Waters) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				pressed_main_button.emit(row, column, which)
			MOUSE_BUTTON_RIGHT:
				pressed_second_button.emit(row, column, which)


func _on_button_mouse_entered(which : E.Waters):
	mouse_entered.emit(row, column, which)


func _on_cell_corner_gui_input(event, which : E.Corner):
	if wall_editor_active:
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					pressed_main_corner_button.emit(row, column, which)
				MOUSE_BUTTON_RIGHT:
					pressed_second_corner_button.emit(row, column, which)


func _on_cell_corner_mouse_entered(which : E.Corner):
	if wall_editor_active:
		mouse_entered_corner_button.emit(row, column, which)
