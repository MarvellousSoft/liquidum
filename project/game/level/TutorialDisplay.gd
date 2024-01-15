extends MarginContainer

const FADE_SPEED = 4.0

@onready var TutContainer = %TutorialCenterContainer

var active = false
var tutorials = []
var idx = 0

func _ready():
	modulate.a = 0.0
	hide()
	setup()


func _process(dt):
	Global.alpha_fade_node(dt, self, active, FADE_SPEED, true)


func setup():
	tutorials = []
	idx = 0
	for section_number in LevelLister.count_all_game_sections():
		for level_number in LevelLister.count_section_levels(section_number + 1):
			var data = FileManager.load_level_data(section_number + 1, level_number + 1)
			if not data.tutorial.is_empty() and\
			   LevelLister.get_max_unlocked_level(section_number + 1) >= level_number + 1:
				tutorials.append(data.tutorial)
	
	update_tutorial()
	%Back.visible = tutorials.size() > 1
	%Forward.visible = tutorials.size() > 1


func enable():
	if tutorials.is_empty():
		return
	active = true


func disable():
	active = false


func is_active() -> bool:
	return active


func update_tutorial():
	if not tutorials.is_empty():
		for child in TutContainer.get_children():
			TutContainer.remove_child(child)
		TutContainer.add_child(Global.get_tutorial(tutorials[idx]))


func _on_back_pressed():
	idx = (idx - 1)%tutorials.size()
	update_tutorial()

func _on_forward_pressed():
	idx = (idx + 1)%tutorials.size()
	update_tutorial()


func _on_close_button_pressed():
	disable()

func _input(event: InputEvent) -> void:
	if active and event.is_action_pressed(&"return"):
		disable()
		accept_event()
