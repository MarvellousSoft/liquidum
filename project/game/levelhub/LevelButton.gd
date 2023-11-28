extends Control

@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect

var my_section := -1
var my_level := -1


func _ready():
	ShaderEffect.material = ShaderEffect.material.duplicate()
	ShaderEffect.material.set_shader_parameter("rippleRate", randf_range(1.6, 3.5))


func setup(section : int, level : int, active : bool) -> void:
	my_section = section
	my_level = level
	MainButton.text = str(level)
	if active:
		enable()
	else:
		disable()


func set_effect_alpha(value : float) -> void:
	ShaderEffect.material.set_shader_parameter("alpha", value)


func enable() -> void:
	MainButton.disabled = false
	ShaderEffect.show()


func disable() -> void:
	MainButton.disabled = true
	ShaderEffect.hide()


func _on_button_pressed():
	if my_level != -1 and my_section != -1:
		var level_data := FileManager.load_level_data(my_section, my_level)
		var level_name := LevelLister.level_name(my_section, my_level)
		var grid := GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution)
		# TODO: Display level_data.full_name somewhere
		var level_node := Global.create_level(grid, level_name)
		TransitionManager.push_scene(level_node)