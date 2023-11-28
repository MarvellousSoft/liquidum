extends Control

const ALPHA_SPEED = 3.0

signal enable_focus(pos : Vector2, my_session : int)
signal disable_focus()

@onready var AnimPlayer = $AnimationPlayer
@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect
@onready var Levels = $Levels


var my_session := -1
var focused := false


func _ready():
	Levels.modulate.a = 0.0
	Levels.hide()
	AnimPlayer.play("float", -1, randf_range(.5, .75))
	AnimPlayer.seek(randf_range(0.0, AnimPlayer.current_animation_length))


func _process(dt):
	if focused:
		Levels.modulate.a = min(Levels.modulate.a + ALPHA_SPEED*dt, 1.0)
		if Levels.modulate.a > 0.0:
			Levels.show()
	else:
		Levels.modulate.a = max(Levels.modulate.a - ALPHA_SPEED*dt, 0.0)
		if Levels.modulate.a <= 0.0:
			Levels.hide()

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
	enable_focus.emit(global_position, my_session)


func unfocus():
	focused = false
	disable_focus.emit()


func setup(session, _num_levels) -> void:
	my_session = session


func _on_button_pressed():
	focus()
