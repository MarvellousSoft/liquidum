extends Cell

const DIAGONAL_BUTTON_MASK = preload("res://assets/images/ui/cell/diagonal_button_mask.png")
const SURFACE_THRESHOLD = 0.7
const BOAT_ALPHA_SPEED = 1.0
const WATER_SPEED_RATIO = 7.0
const MIN_BOAT_ANIM_SPEED = .7
const MAX_BOAT_ANIM_SPEED = .9
const EPS = 0.1
const HIGHLIGHT_SPEED = 5.0
const PREVIEW_MAX_ALPHA = 0.4
const PREVIEW_ALPHA_SPEED = 1.6

signal pressed_main_button(i: int, j: int, which: E.Waters)
signal pressed_second_button(i: int, j: int, which: E.Waters)
signal block_entered
signal override_mouse_entered(i: int, j: int, which: E.Waters)

@onready var Previews = {
	E.Waters.Single: $Preview/Single,
	E.Waters.TopLeft: $Preview/TopLeft,
	E.Waters.TopRight: $Preview/TopRight,
	E.Waters.BottomLeft: $Preview/BottomLeft,
	E.Waters.BottomRight: $Preview/BottomRight,
}
@onready var Waters = {
	E.Waters.Single: $Waters/Single,
	E.Waters.TopLeft: $Waters/TopLeft,
	E.Waters.TopRight: $Waters/TopRight,
	E.Waters.BottomLeft: $Waters/BottomLeft,
	E.Waters.BottomRight: $Waters/BottomRight,
}
@onready var NoContent = {
	E.Waters.Single: {
		"water": $NoContent/Single/Water,
		"boat": $NoContent/Single/Boat,
	},
	E.Waters.TopLeft: {
		"water": $NoContent/TopLeft/Water,
		"boat": $NoContent/TopLeft/Boat,
	},
	E.Waters.TopRight: {
		"water": $NoContent/TopRight/Water,
		"boat": $NoContent/TopRight/Boat,
	},
	E.Waters.BottomLeft: {
		"water": $NoContent/BottomLeft/Water,
		"boat": $NoContent/BottomLeft/Boat,
	},
	E.Waters.BottomRight: {
		"water": $NoContent/BottomRight/Water,
		"boat": $NoContent/BottomRight/Boat,
	},
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
	#E.Walls.DecDiag: $Hints/Dec,
	#E.Walls.IncDiag: $Hints/Inc,
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
@onready var BoatPreview = $BoatPreview
@onready var Errors = {
	E.Waters.Single: $Errors/Single,
	E.Waters.TopLeft: $Errors/TopLeft,
	E.Waters.TopRight: $Errors/TopRight,
	E.Waters.BottomLeft: $Errors/BottomLeft,
	E.Waters.BottomRight: $Errors/BottomRight,
}
@onready var BoatAnim = $Boat/AnimationPlayer
@onready var AnimPlayer = $AnimationPlayer
@onready var Highlight = %Highlight

var disabled := false
var row : int
var column : int
var type : E.CellType
var grid: GridView
var water_flags = {
	E.Waters.Single: false,
	E.Waters.TopLeft: false,
	E.Waters.TopRight: false,
	E.Waters.BottomLeft: false,
	E.Waters.BottomRight: false,
}
var preview_water_flags = {
	E.Waters.Single: false,
	E.Waters.TopLeft: false,
	E.Waters.TopRight: false,
	E.Waters.BottomLeft: false,
	E.Waters.BottomRight: false,
}
var preview_boat_flag := false
var boat_flag := false
var highlight := false
var editor_mode := false

func _ready():
	Highlight.modulate.a = 0.0
	for water in Waters.values():
		water.material = water.material.duplicate()
	for preview in Previews.values():
		preview.material = preview.material.duplicate()
		preview.material.set_shader_parameter("final_alpha", 0.0)
		preview.material.set_shader_parameter("level", 1.0)
	BoatAnim.seek(randf_range(0.0, BoatAnim.current_animation_length), true)
	BoatAnim.speed_scale = randf_range(MIN_BOAT_ANIM_SPEED, MAX_BOAT_ANIM_SPEED)


func _process(dt):
	if grid:
		for corner in E.Waters.values():
			if water_flags[corner]:
				increase_water_level(corner, dt)
			else:
				decrease_water_level(corner, dt)
			var cur_alpha = get_final_alpha(Previews[corner])
			if preview_water_flags[corner]:
				cur_alpha = min(cur_alpha + dt*PREVIEW_ALPHA_SPEED, PREVIEW_MAX_ALPHA)
			else:
				cur_alpha = max(cur_alpha - dt*PREVIEW_ALPHA_SPEED, 0.0)
			set_final_alpha(Previews[corner], cur_alpha)
			Global.alpha_fade_node(dt, Boat, boat_flag)
			Global.alpha_fade_node(dt, BoatPreview, preview_boat_flag, PREVIEW_ALPHA_SPEED, false, PREVIEW_MAX_ALPHA)

		Global.alpha_fade_node(dt, Highlight, highlight)


func enable():
	disabled = false
	for button in Buttons.values():
		button.disabled = false


func disable():
	disabled = true
	highlight = false
	for button in Buttons.values():
		button.disabled = true


func setup(grid_ref : Node, data : GridModel.CellModel, i : int, j : int, editor : bool, startup_delay : float, fast_startup : bool) -> void:
	editor_mode = editor
	grid = grid_ref
	row = i
	column = j
	for water in Waters.values():
		water.show()
		set_water_level(water, 0.)
	for nocontent in NoContent.values():
		nocontent.water.hide()
		nocontent.boat.hide()
	for preview in Previews.values():
		set_final_alpha(preview, 0.)
	for error in Errors.values():
		error.modulate.a = 0.0
	Boat.modulate.a = 0.0
	BoatPreview.modulate.a = 0.0
	copy_data(data)

	if not editor_mode and not fast_startup:
		await get_tree().create_timer((i+1)*(j+1)*startup_delay).timeout
		AnimPlayer.play("startup")
	else:
		modulate.a = 1.0


func set_highlight(value: bool) -> void:
	if disabled:
		return
	highlight = value


func fast_update_waters() -> void:
	for flag in water_flags.keys():
		if water_flags[flag]:
			set_water_level(Waters[flag], SURFACE_THRESHOLD if grid.is_at_surface(row, column, flag) else 1.0)
		else:
			set_water_level(Waters[flag], 0.)


func play_error(which : E.Waters) -> void:
	Errors[which].get_node("AnimationPlayer").play("error")


func get_type() -> E.CellType:
	return type


func copy_data(data: GridModel.CellModel) -> void:
	# Need to remove water when changing walls
	remove_water()
	remove_nowater()
	set_boat(false)
	for wall in E.Walls.values():
		var has_wall := data.wall_at(wall)
		Walls[wall].set_visible(has_wall)
		if Hints.has(wall):
			Hints[wall].set_visible(not has_wall)
	type = data.cell_type()
	for button in Buttons.values():
		button.hide()
	match type:
		E.CellType.Single:
			Buttons[E.Single].show()
		E.CellType.IncDiag:
			Buttons[E.TopLeft].show()
			Buttons[E.BottomRight].show()
		E.CellType.DecDiag:
			Buttons[E.TopRight].show()
			Buttons[E.BottomLeft].show()
		_:
			push_error("Not a valid type of cell:" + str(type))
	update_blocks(data)


func update_blocks(data: GridModel.CellModel) -> void:
	for b in Blocks.values():
		b.hide()
	if data.block_full():
		set_block(E.Waters.Single)
	else:
		for corner in E.Corner.values():
			if data.block_at(corner):
				set_block(corner)



func set_block(block : E.Waters) -> void:
	Blocks[block].show()
	if not editor_mode:
		Buttons[block].hide()


func has_boat() -> bool:
	return boat_flag


func set_boat(value : bool) -> void:
	boat_flag = value


func set_boat_preview(value : bool) -> void:
	preview_boat_flag = value


func remove_water() -> void:
	for flag in water_flags.keys():
		water_flags[flag] = false


func set_water(water : E.Waters, value: bool) -> void:
	set_boat(false)
	water_flags[water] = value


func remove_nowater() -> void:
	for nocontent in NoContent.values():
		nocontent.water.hide()


func remove_noboat() -> void:
	for nocontent in NoContent.values():
		nocontent.boat.hide()


func set_water_preview(water : E.Waters, value: bool) -> void:
	preview_water_flags[water] = value


func remove_all_preview() -> void:
	for water in Previews.keys():
		preview_water_flags[water] = false
	preview_boat_flag = false


func set_nowater(which : E.Waters, value: bool) -> void:
	NoContent[which].water.visible = value



func set_noboat(which : E.Waters, value: bool) -> void:
	NoContent[which].boat.visible = value


func get_water_flag(corner : E.Waters) -> bool:
	return water_flags[corner]


func get_corner_water_level(corner : E.Waters) -> float:
	return Waters[corner].material.get_shader_parameter("level")


func set_water_level(water: TextureRect, value: float) -> void:
	water.material.set_shader_parameter("level", value)


func get_final_alpha(water: TextureRect) -> float:
	return water.material.get_shader_parameter("final_alpha")


func set_final_alpha(water: TextureRect, value: float) -> void:
	water.material.set_shader_parameter("final_alpha", value)

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


func _on_button_gui_input(event, which : E.Waters) -> void:
	if Buttons[which].disabled:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				pressed_main_button.emit(row, column, which)
			MOUSE_BUTTON_RIGHT:
				pressed_second_button.emit(row, column, which)


func _on_button_mouse_entered(which : E.Waters):
	if row != null and column != null:
		override_mouse_entered.emit(row, column, which)


func _on_block_mouse_entered():
	block_entered.emit(row, column)
