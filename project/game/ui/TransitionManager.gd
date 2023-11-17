extends CanvasLayer

signal transition_finished

@onready var Effect: ColorRect = $Effect
@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer

var active = false


func _ready():
	Effect.material.set_shader_parameter("cutoff", 1.0)
	visible = false


func change_scene(scene: Node) -> void:
	active = true
	visible = true
	AudioManager.play_sfx("wave_in")
	
	AnimPlayer.play_backwards("transition_out")
	
	
	await AnimPlayer.animation_finished
	
	get_tree().unload_current_scene()
	get_tree().root.add_child(scene)
	
	await get_tree().create_timer(.2).timeout
	
	AudioManager.play_sfx("wave_out")
	AnimPlayer.play("transition_out")
	
	await AnimPlayer.animation_finished
	
	visible = false
	active = false
	
	transition_finished.emit()
