class_name LevelButton
extends Control

const STYLES = {
	"normal": {
		"normal": {
			"normal": preload("res://assets/ui/LevelButton/NormalStyle.tres"),
			"hover": preload("res://assets/ui/LevelButton/HoverStyle.tres"),
			"pressed": preload("res://assets/ui/LevelButton/PressedStyle.tres"),
		},
		"completed": {
			"normal": preload("res://assets/ui/LevelButton/CompletedNormalStyle.tres"),
			"hover": preload("res://assets/ui/LevelButton/CompletedHoverStyle.tres"),
			"pressed": preload("res://assets/ui/LevelButton/CompletedPressedStyle.tres"),
		}
	},
	"dark": {
		"normal": {
			"normal": preload("res://assets/ui/LevelButton/NormalStyle.tres"),
			"hover": preload("res://assets/ui/LevelButton/HoverStyle.tres"),
			"pressed": preload("res://assets/ui/LevelButton/PressedStyle.tres"),
		},
		"completed": {
			"normal": preload("res://assets/ui/LevelButton/CompletedNormalDarkStyle.tres"),
			"hover": preload("res://assets/ui/LevelButton/CompletedHoverDarkStyle.tres"),
			"pressed": preload("res://assets/ui/LevelButton/CompletedPressedDarkStyle.tres"),
		}
	},
}

signal pressed
signal had_first_win
signal loaded_endless(button: LevelButton)

@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect
@onready var OngoingSolution = %OngoingSolution
@onready var AnimPlayer = $AnimationPlayer
@onready var HardIcon: TextureRect = $HardIcon

var my_section := -1
var my_level := -1
var workshop_id := -1
var workshop_author := ""
var data = false
var lister: LevelLister = null

var disabled: bool :
	get:
		return MainButton.disabled
	set(x):
		if x:
			disable()
		else:
			enable()
		


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	ShaderEffect.material = ShaderEffect.material.duplicate()
	ShaderEffect.material.set_shader_parameter("rippleRate", randf_range(1.6, 3.5))

func extra_level() -> bool:
	return lister == ExtraLevelLister

func setup(section : int, level: int, active : bool, extra: bool) -> void:
	%AlternateText.queue_free()
	lister = ExtraLevelLister as LevelLister if extra else CampaignLevelLister as LevelLister
	my_section = section
	my_level = level
	if level == -1:
		assert(extra)
		MainButton.text = "∞"
	else:
		MainButton.text = str(my_level)
	
	HardIcon.visible = lister.is_hard(section, level)
	if active:
		enable()
		if my_level == -1:
			data = ExtraLevelLister.get_endless_user_save(section)
		else:
			data = lister.get_level_user_save(section, my_level)
		change_style_boxes(data and data.is_completed())
		set_ongoing_solution(data and not data.is_solution_empty())
	else:
		set_ongoing_solution(false)
		disable()

func setup_workshop(level_data: LevelData, id: int, author: String) -> void:
	workshop_id = id
	workshop_author = author
	MainButton.text = ""
	HardIcon.hide()
	%AlternateText.show()
	if randf() < 0.5:
		AnimPlayer.play("float")
	else:
		AnimPlayer.play_backwards("float")
	AnimPlayer.speed_scale = 0.9 + randf() * 0.2
	AnimPlayer.advance(AnimPlayer.current_animation_length * randf())
	if level_data != null:
		%AlternateText.text = level_data.full_name
		enable()
		data = FileManager.load_level(str(id))
		change_style_boxes(data and data.is_completed())
		set_ongoing_solution(data and not data.is_solution_empty())
	else:
		%AlternateText.text = "NOT_INSTALLED"
		set_ongoing_solution(false)


func unlock():
	AnimPlayer.play("unlock")


func set_ongoing_solution(status: bool) -> void:
	OngoingSolution.visible = status


func change_style_boxes(completed : bool) -> void:
	var style_theme = STYLES.dark if Profile.get_option("dark_mode") else STYLES.normal
	var styles = style_theme.completed if completed else style_theme.normal
	MainButton.add_theme_stylebox_override("normal", styles.normal)
	MainButton.add_theme_stylebox_override("hover", styles.hover)
	MainButton.add_theme_stylebox_override("pressed", styles.pressed)


func set_effect_alpha(value : float) -> void:
	ShaderEffect.material.set_shader_parameter("alpha", value)


func enable() -> void:
	MainButton.disabled = false
	ShaderEffect.show()
	HardIcon.modulate.a = 1.0

func disable() -> void:
	MainButton.disabled = true
	ShaderEffect.hide()
	HardIcon.modulate.a = 0.0


func load_existing_endless() -> void:
	var gdata := FileManager.load_extra_endless_level(my_section)
	if gdata == null:
		return
	var key := ExtraLevelLister.endless_level_name(my_section)
	var level_node := Global.create_level(GridImpl.import_data(gdata.grid_data, GridModel.LoadMode.Solution), key, "", "", ["random", key])
	level_node.seed_str = gdata.seed_str
	level_node.manually_seeded = gdata.manually_seeded
	level_node.extra_section = my_section
	level_node.won.connect(_completed_endless)
	if Global.play_new_dif_again == -1:
		TransitionManager.push_scene(level_node)
	else:
		Global.play_new_dif_again = -1
		TransitionManager.change_scene(level_node)

func _completed_endless(info: Level.WinInfo) -> void:
	var u_data := UserData.current()
	u_data.bump_endless_completed(my_section)
	if info.mistakes < 3:
		u_data.bump_endless_good(my_section)
	UserData.save()

func gen_and_load_endless() -> void:
	loaded_endless.emit(self)
	# There might be an existing save
	FileManager.clear_level(ExtraLevelLister.endless_level_name(my_section))
	var gen := RandomLevelGenerator.new()
	var seed_int := UserData.current().bump_endless_created(my_section) - 1
	UserData.save()
	var seed_str := str(seed_int)
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash(seed_str)
	var prep := PreprocessedEndless.current(my_section)
	if prep.success_state(seed_int) != 0:
		rng.state = prep.success_state(seed_int)
	GeneratingLevel.enable()
	var grid := await RandomFlavors.gen(gen, rng, ExtraLevelLister.section_endless_flavor(my_section))
	GeneratingLevel.disable()
	if grid == null:
		return
	var gdata := LevelData.new("", "", grid.export_data(), "")
	gdata.manually_seeded = false
	gdata.seed_str = seed_str
	FileManager.save_extra_endless_level(my_section, gdata)
	load_existing_endless()

func _on_button_pressed():
	if my_level != -1 and my_section != -1:
		var level_data := lister.get_level_data(my_section, my_level)
		var level_name := lister.level_name(my_section, my_level)
		var grid := GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution)
		var section := -1 if extra_level() else my_section
		var level_number := -1 if extra_level() else my_level
		var level_node := Global.create_level(grid, level_name, level_data.full_name, level_data.description, [lister.level_stat(my_section, my_level)], level_number, section)
		if extra_level():
			level_node.extra_section = my_section
			level_node.extra_level_number = my_level
		level_node.won.connect(_level_completed)
		level_node.had_first_win.connect(_on_level_had_first_win)
		TransitionManager.push_scene(level_node)
	elif my_level == -1 and my_section != -1:
		assert(extra_level())
		var has_endless_level := (ExtraLevelLister.get_endless_user_save(my_section) != null)
		if has_endless_level:
			if ConfirmationScreen.start_confirmation(&"CONFIRMATION_NEW_ENDLESS", &"ENDLESS_CONTINUE", &"ENDLESS_NEW"):
				if await ConfirmationScreen.pressed:
					load_existing_endless()
				else:
					await gen_and_load_endless()
			else:
				load_existing_endless()
		else:
			await gen_and_load_endless()
	elif workshop_id != -1:
		var level_data := WorkshopLevelButton.load_level_from_id(workshop_id)
		if level_data == null:
			return
		var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), str(workshop_id), level_data.full_name, level_data.description, ["workshop"])
		level.set_author(workshop_author)
		level.workshop_id = workshop_id
		level.won.connect(WorkshopLevelButton._level_completed)
		TransitionManager.push_scene(level)



func _level_completed(info: Level.WinInfo) -> void:
	if info.first_win and not extra_level():
		# The overiders may be coroutines
		@warning_ignore("redundant_await")
		await StatsTracker.instance().update_campaign_stats()


func _on_level_had_first_win():
	had_first_win.emit(self)


func _on_button_mouse_entered():
	if not $Button.disabled:
		AudioManager.play_sfx("button_hover")
		mouse_entered.emit()


func _on_button_mouse_exited():
	mouse_exited.emit()


func _on_dark_mode_changed(_is_dark : bool):
	if data:
		change_style_boxes(data.is_completed())
	else:
		change_style_boxes(false)
