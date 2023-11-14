extends CanvasLayer

signal transition_finished

@onready var Effect = $Effect
@onready var AnimPlayer = $AnimationPlayer

var active = false


func _ready():
	Effect.material.set_shader_parameter("cutoff", 1.0)
	visible = false


func change_scene(scene_path):
	active = true
	visible = true
	AudioManager.play_sfx("wave_in")
	
	AnimPlayer.play_backwards("transition_out")
	
	
	await AnimPlayer.animation_finished
	
	get_tree().change_scene_to_file(scene_path)
	
	await get_tree().create_timer(.2).timeout
	
	AudioManager.play_sfx("wave_out")
	AnimPlayer.play("transition_out")
	
	await AnimPlayer.animation_finished
	
	visible = false
	active = false
	
	emit_signal("transition_finished")
