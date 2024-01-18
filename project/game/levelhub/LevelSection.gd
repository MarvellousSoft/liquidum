extends Control

const LEVELBUTTON = preload("res://game/levelhub/LevelButton.tscn")
const ALPHA_SPEED = 3.0
const LERP = 2.0
const DIST_EPS = .4
const CENTRAL_POS = Vector2(-103, -135)
const RADIUS = 500
const ELLIPSE_RATIO = {
	"desktop": Vector2(1.1, .75),
	"mobile": Vector2(.75, 1.1),
}
const LEVELS_SCALE = {
	"desktop": Vector2(.5, .5),
	"mobile": Vector2(.4, .4),
}
const BACK_POSITION = {
	"desktop": Vector2(-791, -447),
	"mobile": Vector2(-330, -477),
}

const STYLES = {
	"normal": {
		"normal": preload("res://assets/ui/SectionButton/NormalStyle.tres"),
		"hover": preload("res://assets/ui/SectionButton/HoverStyle.tres"),
		"pressed": preload("res://assets/ui/SectionButton/PressedStyle.tres"),
	},
	"completed": {
		"normal": preload("res://assets/ui/SectionButton/CompletedNormalStyle.tres"),
		"hover": preload("res://assets/ui/SectionButton/CompletedHoverStyle.tres"),
		"pressed": preload("res://assets/ui/SectionButton/CompletedPressedStyle.tres"),
	}
}

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()

@onready var AnimPlayer = $AnimationPlayer
@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect
@onready var Levels = $Levels
@onready var BackButton = $BackButton
@onready var MouseBlocker = $Button/MouseBlocker
@onready var OngoingSolution = %OngoingSolution
@onready var LevelCount = %LevelCount
@onready var SectionNumber = %SectionNumber
@onready var LevelInfoContainer = %LevelInfoContainer


var my_section := -1
var focused := false
var showing_level_info := false
var hub = null


func _ready():
	AnimPlayer.play("float")
	OngoingSolution.hide()
	ShaderEffect.material = ShaderEffect.material.duplicate()
	ShaderEffect.material.set_shader_parameter("rippleRate", randf_range(1.6, 3.5))
	Levels.modulate.a = 0.0
	LevelInfoContainer.modulate.a = 0.0
	SectionNumber.modulate.a = 1.0
	Levels.hide()
	MouseBlocker.hide()
	AnimPlayer.seek(randf_range(0.0, AnimPlayer.current_animation_length))
	BackButton.position = BACK_POSITION.mobile if Global.is_mobile else BACK_POSITION.desktop


func _input(event):
	if event.is_action_pressed("return") and focused:
		_on_back_button_pressed()


func _process(dt):
	for node in [Levels, BackButton]:
		Global.alpha_fade_node(dt, node, focused, ALPHA_SPEED, true)
	for node in [OngoingSolution, LevelCount]:
		Global.alpha_fade_node(dt, node, not focused, ALPHA_SPEED)
	Global.alpha_fade_node(dt, LevelInfoContainer, showing_level_info and focused, ALPHA_SPEED)
	Global.alpha_fade_node(dt, SectionNumber, not focused or not showing_level_info, ALPHA_SPEED)
	if focused:
		if MainButton.position != CENTRAL_POS:
			MainButton.position = lerp(MainButton.position, CENTRAL_POS, clamp(LERP, 0.0, 1.0))
			if MainButton.position.distance_to(CENTRAL_POS) < DIST_EPS:
				MainButton.position = CENTRAL_POS
	for level in Levels.get_children():
		level.set_effect_alpha(Levels.modulate.a)


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST and focused:
		_on_back_button_pressed()


func setup(hub_ref, section, unlocked_levels) -> void:
	hub = hub_ref
	set_number(section)
	for button in Levels.get_children():
		Levels.remove_child(button)
		button.queue_free()
	
	Levels.scale = LEVELS_SCALE.mobile if Global.is_mobile else LEVELS_SCALE.desktop
	
	var total_levels = LevelLister.get_levels_in_section(my_section)
	for i in range(1, total_levels + 1):
		var button = LEVELBUTTON.instantiate()
		Levels.add_child(button)
		position_level_button(button, total_levels, i)
		var has_unlock_anim = (my_section == hub.section_to_unlock and i == hub.level_to_unlock)
		button.setup(my_section, i, i <= unlocked_levels and not has_unlock_anim)
		button.mouse_exited.connect(_on_level_button_mouse_exited)
		button.mouse_entered.connect(_on_level_button_mouse_entered.bind(i))
		button.had_first_win.connect(_on_level_first_win)
		
	OngoingSolution.visible = LevelLister.count_section_ongoing_solutions(my_section) > 0
	update_level_count_label()
	update_style_boxes(is_section_completed())


func enable() -> void:
	AnimPlayer.speed_scale = randf_range(.35, .55)
	MainButton.disabled = false
	ShaderEffect.show()
	LevelCount.show()


func disable() -> void:
	AnimPlayer.speed_scale = randf_range(.1, .15)
	MainButton.disabled = true
	ShaderEffect.hide()
	LevelCount.hide()


func set_number(section: int) -> void:
	my_section = section
	SectionNumber.text = str(section)


func focus():
	AnimPlayer.pause()
	focused = true
	MouseBlocker.show()
	enable_focus.emit(global_position, my_section)


func unfocus():
	AnimPlayer.play("float")
	focused = false
	MouseBlocker.hide()
	disable_focus.emit()


func show_level_info(level_name: String, completed: bool, time: float, mistakes: int) -> void:
	showing_level_info = true
	%LevelName.text = level_name
	if completed:
		%Completed.text = tr("COMPLETED_LEVEL")
	else:
		%Completed.text = tr("NOT_COMPLETED_LEVEL")
	if time != -1:
		%BestTime.text = tr("BEST_TIME") % get_formatted_time(time)
	else:
		%BestTime.text = tr("BEST_TIME") % "-"
	if mistakes != -1:
		%BestMistakes.text = tr("BEST_MISTAKES") % str(mistakes)
	else:
		%BestMistakes.text = tr("BEST_MISTAKES") % "-"


func hide_level_info():
	showing_level_info = false


func get_formatted_time(time: float) -> String:
	var t = int(time)
	var hours = t/3600
	var minutes = t%3600/60
	var seconds = t%60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours,minutes,seconds]
	else:
		return "%02d:%02d" % [minutes,seconds]


func position_level_button(button, total_levels, i):
	var angle = PI/2 + i*2*PI/float(total_levels)
	var sc = Levels.scale.x
	var ellipse = ELLIPSE_RATIO.mobile if Global.is_mobile else ELLIPSE_RATIO.desktop
	button.position = Vector2(
		cos(angle)*RADIUS*ellipse.x/sc,
		sin(angle)*RADIUS*ellipse.y/sc,
	)


func unlock():
	AnimPlayer.play("unlock")


func unlock_level(level):
	Levels.get_child(level - 1).unlock()


func disable_level(level):
	Levels.get_child(level - 1).disable()


func is_section_completed():
	return LevelLister.count_completed_section_levels(my_section) >=\
		   LevelLister.count_section_levels(my_section)


func update_level_count_label():
	LevelCount.text = "%d/%d" % \
		[LevelLister.count_completed_section_levels(my_section),\
		 LevelLister.count_section_levels(my_section)]


func update_style_boxes(completed : bool):
	var styles = STYLES.completed if completed else STYLES.normal
	MainButton.add_theme_stylebox_override("normal", styles.normal)
	MainButton.add_theme_stylebox_override("hover", styles.hover)
	MainButton.add_theme_stylebox_override("pressed", styles.pressed)


func _on_button_pressed():
	AudioManager.play_sfx("zoom_in")
	focus()


func _on_back_button_pressed():
	AudioManager.play_sfx("zoom_out")
	unfocus()


func _on_level_button_mouse_entered(level_number : int):
	var save = FileManager.load_level(LevelLister.level_name(my_section, level_number))
	var data = FileManager.load_level_data(my_section, level_number)
	if save:
		show_level_info(data.full_name, save.is_completed(), save.best_time_secs, save.best_mistakes)
	else:
		show_level_info(data.full_name, false, -1, -1)


func _on_level_button_mouse_exited():
	hide_level_info()


func _on_level_first_win(button):
	var section = button.my_section
	var completed_levels = LevelLister.count_completed_section_levels(section)
	var section_levels = LevelLister.count_section_levels(section)
	if completed_levels < section_levels - LevelLister.get_max_unlocked_levels():
		hub.prepare_to_unlock_level(section, LevelLister.get_max_unlocked_level(section))
	elif (completed_levels == section_levels - LevelLister.get_max_unlocked_levels()) and \
		 section < LevelLister.count_all_game_sections():
		hub.unlock_section(section)
