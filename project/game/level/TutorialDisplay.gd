extends MarginContainer

const FADE_SPEED = 4.0
const THEMES = {
	"normal": {
		"panel": preload("res://assets/ui/TutorialPanel.tres"),
	},
	"dark": {
		"panel": preload("res://assets/ui/TutorialPanelDark.tres"),
	},
}

signal tutorial_closed

@onready var TutContainer = %TutorialCenterContainer

var active = false
var tutorials = []
var idx = 0

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	modulate.a = 0.0
	hide()
	setup()


func _process(dt):
	Global.alpha_fade_node(dt, self, active, FADE_SPEED, true)


func _input(event: InputEvent) -> void:
	if active and event.is_action_pressed(&"return"):
		disable()
		accept_event()


func setup():
	tutorials = []
	for section_number in range(1, 50):
		if not CampaignLevelLister.has_section(section_number) or (section_number > 1 and not CampaignLevelLister.section_complete(section_number - 1)):
			break
		for level_number in range(1, CampaignLevelLister.get_max_unlocked_level(section_number) + 1, 1):
			var data := FileManager.load_campaign_level_data(section_number, level_number)
			if not data.tutorial.is_empty() and Global.has_tutorial(data.tutorial):
					tutorials.append(data.tutorial)
	for section_number in range(1, ExtraLevelLister.count_all_game_sections(false)):
		for level_number in range(1, ExtraLevelLister.get_max_unlocked_level(section_number)):
			var data = ExtraLevelLister.get_level_data(section_number, level_number)
			if not data.tutorial.is_empty():
				tutorials.append(data.tutorial)
				
	idx = tutorials.size() - 1
	update_tutorial()
	%Back.visible = tutorials.size() > 1
	%Forward.visible = tutorials.size() > 1

func show_level_tutorial(section: int, level: int, is_extra := false) -> void:
	var data
	if is_extra:
		data = FileManager.load_extra_level_data(section, level)
	else:
		data = FileManager.load_campaign_level_data(section, level)
	if not data.tutorial.is_empty() and Global.has_tutorial(data.tutorial):
		idx = maxi(tutorials.find(data.tutorial), 0)
		update_tutorial()

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
		var tut = Global.get_tutorial(tutorials[idx])
		if tut:
			%Title.text = tut.tutorial_name
			TutContainer.add_child(tut)


func _on_back_pressed():
	idx = (idx - 1)%tutorials.size()
	update_tutorial()

func _on_forward_pressed():
	idx = (idx + 1)%tutorials.size()
	update_tutorial()


func _on_close_button_pressed():
	disable()
	tutorial_closed.emit()


func _on_dark_mode_changed(is_dark : bool):
	var themes = THEMES.dark if is_dark else THEMES.normal
	theme = Global.get_theme(is_dark)
	%PanelContainer.add_theme_stylebox_override("panel", themes.panel)
