extends CanvasLayer

signal transition_finished

@onready var Effect: ColorRect = $Effect
@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer

var active := false
var stack: Array[Node] = []


func _ready():
	Effect.material.set_shader_parameter("cutoff", 1.0)
	visible = false

func pop_scene() -> void:
	if not stack.is_empty():
		var scene: Node = stack.pop_back()
		change_scene(scene, false)

func push_scene(scene: Node) -> void:
	change_scene(scene, true)

func change_scene(scene: Node, add_to_stack := false) -> void:
	active = true
	visible = true
	AudioManager.play_sfx("wave_in")
	
	AnimPlayer.play_backwards("transition_out")
	
	
	await AnimPlayer.animation_finished
	
	var tree := get_tree()
	if add_to_stack:
		var old_scene := tree.current_scene
		tree.root.remove_child(old_scene)
		stack.push_back(old_scene)
	else:
		tree.unload_current_scene()
	tree.root.add_child(scene)
	tree.current_scene = scene
	
	await get_tree().create_timer(.2).timeout
	
	AudioManager.play_sfx("wave_out")
	AnimPlayer.play("transition_out")
	
	await AnimPlayer.animation_finished
	
	visible = false
	active = false
	
	transition_finished.emit()
