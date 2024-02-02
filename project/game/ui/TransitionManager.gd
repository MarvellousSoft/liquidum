extends CanvasLayer

signal transition_finished

const COLORS = {
	"dark_mode": {
		"water_color": Color("000924"),
		"foam_color": Color("093659"),
	},
	"light_mode": {
		"water_color": Color("31b0b0"),
		"foam_color": Color("abffd1"),
	}
}

@onready var Effect: ColorRect = $Effect
@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer

var active := false
var stack: Array[Node] = []


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_toggled)
	Effect.material.set_shader_parameter("cutoff", 1.0)
	visible = false

func pop_scene() -> void:
	if not stack.is_empty():
		var scene: Node = stack.pop_back()
		await change_scene(scene, false)

func push_scene(scene: Node) -> void:
	await change_scene(scene, true)

func change_scene(scene: Node, add_to_stack := false) -> void:
	active = true
	visible = true

	AudioManager.play_sfx("wave_in")
	AnimPlayer.play_backwards("transition_out")
	await AnimPlayer.animation_finished

	var watch := Stopwatch.new()
	var tree := get_tree()
	if add_to_stack:
		var old_scene := tree.current_scene
		tree.root.remove_child(old_scene)
		stack.push_back(old_scene)
	else:
		tree.unload_current_scene()
	tree.root.add_child(scene)
	tree.current_scene = scene
	var wait := 0.2 - watch.elapsed()
	if wait > 0:
		await get_tree().create_timer(wait).timeout

	AudioManager.play_sfx("wave_out")
	AnimPlayer.play("transition_out")

	await AnimPlayer.animation_finished
	
	visible = false
	active = false
	
	transition_finished.emit()


func _on_dark_mode_toggled(dark_mode):
	var colors = COLORS.dark_mode if dark_mode else COLORS.light_mode
	Effect.material.set_shader_parameter("water_color", colors.water_color)
	Effect.material.set_shader_parameter("foam_color", colors.foam_color)
