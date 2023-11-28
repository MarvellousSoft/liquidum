extends Control

const LEVELBUTTON = preload("res://game/levelhub/LevelButton.tscn")
const ALPHA_SPEED = 3.0
const LERP = 2.0
const DIST_EPS = .4
const CENTRAL_POS = Vector2(-103, -135)
const RADIUS = 500
const ELLIPSE_RATIO = Vector2(1.1, .75)

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()

@onready var AnimPlayer = $AnimationPlayer
@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect
@onready var Levels = $Levels
@onready var BackButton = $BackButton
@onready var MouseBlocker = $Button/MouseBlocker


var my_section := -1
var focused := false


func _ready():
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
		if MainButton.position != CENTRAL_POS:
			MainButton.position = lerp(MainButton.position, CENTRAL_POS, clamp(LERP, 0.0, 1.0))
			if MainButton.position.distance_to(CENTRAL_POS) < DIST_EPS:
				MainButton.position = CENTRAL_POS
	else:
		for node in [Levels, BackButton]:
			node.modulate.a = max(node.modulate.a - ALPHA_SPEED*dt, 0.0)
			if node.modulate.a <= 0.0:
				node.hide()
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
		button.pressed.connect(unfocus)


func enable() -> void:
	AnimPlayer.speed_scale = randf_range(.35, .55)
	AnimPlayer.play("float")
	MainButton.disabled = false
	ShaderEffect.show()


func disable() -> void:
	AnimPlayer.speed_scale = randf_range(.1, .15)
	AnimPlayer.play("float")
	MainButton.disabled = true
	ShaderEffect.hide()


func focus():
	AnimPlayer.pause()
	focused = true
	MouseBlocker.show()
	enable_focus.emit(global_position, my_section)


func unfocus():
	AnimPlayer.play("float", 2.0)
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


func _on_button_pressed():
	AudioManager.play_sfx("zoom_in")
	focus()


func _on_back_button_pressed():
	AudioManager.play_sfx("zoom_out")
	unfocus()
