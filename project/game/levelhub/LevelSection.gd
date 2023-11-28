extends Control

const ALPHA_SPEED = 3.0

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
	Levels.modulate.a = 0.0
	Levels.hide()
	MouseBlocker.hide()
	AnimPlayer.play("float", -1, randf_range(.5, .75))
	AnimPlayer.seek(randf_range(0.0, AnimPlayer.current_animation_length))


func _process(dt):
	if focused:
		for node in [Levels, BackButton]:
			node.modulate.a = min(node.modulate.a + ALPHA_SPEED*dt, 1.0)
			if node.modulate.a > 0.0:
				node.show()
	else:
		for node in [Levels, BackButton]:
			node.modulate.a = max(node.modulate.a - ALPHA_SPEED*dt, 0.0)
			if node.modulate.a <= 0.0:
				node.hide()
	for level in Levels.get_children():
		level.set_effect_alpha(Levels.modulate.a)


func enable() -> void:
	AnimPlayer.play("float", -1, randf_range(.5, .75))
	MainButton.disabled = false
	ShaderEffect.show()


func disable() -> void:
	AnimPlayer.play("float", -1, randf_range(.2, .3))
	MainButton.disabled = true
	ShaderEffect.hide()


func focus():
	focused = true
	MouseBlocker.show()
	enable_focus.emit(global_position, my_section)


func unfocus():
	focused = false
	MouseBlocker.hide()
	disable_focus.emit()


func setup(section, num_levels) -> void:
	my_section = section
	var idx = 1
	for button in Levels.get_children():
		button.setup(section, idx, idx <= num_levels)
		idx += 1


func _on_button_pressed():
	AudioManager.play_sfx("zoom_in")
	focus()


func _on_back_button_pressed():
	AudioManager.play_sfx("zoom_out")
	unfocus()
