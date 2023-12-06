extends Control

const LEVELBUTTON = preload("res://game/levelhub/LevelButton.tscn")
const ALPHA_SPEED = 3.0
const LERP = 2.0
const DIST_EPS = .4
const CENTRAL_POS = Vector2(-103, -135)
const RADIUS = 500
const ELLIPSE_RATIO = Vector2(1.1, .75)
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


var my_section := -1
var focused := false


func _ready():
	AnimPlayer.play("float")
	OngoingSolution.hide()
	ShaderEffect.material = ShaderEffect.material.duplicate()
	ShaderEffect.material.set_shader_parameter("rippleRate", randf_range(1.6, 3.5))
	Levels.modulate.a = 0.0
	Levels.hide()
	MouseBlocker.hide()
	AnimPlayer.seek(randf_range(0.0, AnimPlayer.current_animation_length))


func _input(event):
	if event.is_action_pressed("return") and focused:
		_on_back_button_pressed()


func _process(dt):
	if focused:
		for node in [Levels, BackButton]:
			node.modulate.a = min(node.modulate.a + ALPHA_SPEED*dt, 1.0)
			if node.modulate.a > 0.0:
				node.show()
		OngoingSolution.modulate.a = max(OngoingSolution.modulate.a - ALPHA_SPEED*dt, 0.0)
		LevelCount.modulate.a = max(LevelCount.modulate.a - ALPHA_SPEED*dt, 0.0)
		if MainButton.position != CENTRAL_POS:
			MainButton.position = lerp(MainButton.position, CENTRAL_POS, clamp(LERP, 0.0, 1.0))
			if MainButton.position.distance_to(CENTRAL_POS) < DIST_EPS:
				MainButton.position = CENTRAL_POS
	else:
		for node in [Levels, BackButton]:
			node.modulate.a = max(node.modulate.a - ALPHA_SPEED*dt, 0.0)
			if node.modulate.a <= 0.0:
				node.hide()
		OngoingSolution.modulate.a = min(OngoingSolution.modulate.a + ALPHA_SPEED*dt, 1.0)
		LevelCount.modulate.a = min(LevelCount.modulate.a + ALPHA_SPEED*dt, 1.0)
	for level in Levels.get_children():
		level.set_effect_alpha(Levels.modulate.a)


func setup(section, unlocked_levels) -> void:
	my_section = section
	for button in Levels.get_children():
		Levels.remove_child(button)
		button.queue_free()
	
	var total_levels = LevelLister.get_levels_in_section(section)
	for i in range(1, total_levels + 1):
		var button = LEVELBUTTON.instantiate()
		Levels.add_child(button)
		position_level_button(button, total_levels, i)
		button.setup(section, i, i <= unlocked_levels)
	
	OngoingSolution.visible = LevelLister.count_section_ongoing_solutions(section) > 0
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


func position_level_button(button, total_levels, i):
	var angle = PI/2 + i*2*PI/float(total_levels)
	var sc = Levels.scale.x
	button.position = Vector2(
		cos(angle)*RADIUS*ELLIPSE_RATIO.x/sc,
		sin(angle)*RADIUS*ELLIPSE_RATIO.y/sc,
	)


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
