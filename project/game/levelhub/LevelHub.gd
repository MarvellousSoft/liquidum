extends Control

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()

@onready var Sections = %Sections

var level_focused := false
var section_focused := -1
var level_to_unlock = -1
var section_to_unlock = -1
## Load extra levels instead of regular campaign levels
@export var extra_levels := false

func _ready() -> void:
	update_sections()

func _process(dt):
	var idx = 1
	for section in Sections.get_children():
		Global.alpha_fade_node(dt, section, not level_focused or idx == section_focused, 4.0, true)
		idx += 1


func _enter_tree() -> void:
	Global.dev_mode_toggled.connect(_on_dev_mode)
	check_unlocks()


func _exit_tree() -> void:
	Global.dev_mode_toggled.disconnect(_on_dev_mode)


func _on_dev_mode(_on: bool) -> void:
	update_sections()


func update_sections() -> void:
	var level_lister: LevelLister = ExtraLevelLister as LevelLister if extra_levels else CampaignLevelLister as LevelLister
	var count: int = level_lister.count_all_game_sections()
	if extra_levels:
		while Sections.get_child_count() > 0:
			var c := Sections.get_child(Sections.get_child_count() - 1)
			Sections.remove_child(c)
			c.queue_free()
	while Sections.get_child_count() < count:
		var c := preload("res://game/levelhub/LevelSection.tscn").instantiate()
		Sections.add_child(c)
		c.enable_focus.connect(_on_level_section_enable_focus)
		c.disable_focus.connect(_on_level_section_disable_focus)
	if extra_levels:
		Sections.columns = int((count + 1) / 2)
	var idx := 1
	for section in Sections.get_children():
		section.set_number(idx)
		var unlocked := level_lister.get_max_unlocked_level(idx)
		if Global.is_dev_mode():
			unlocked = level_lister.count_section_levels(idx)
		if unlocked == 0:
			section.disable()
		else:
			section.enable()
			section.setup(self, idx, unlocked, extra_levels)
		idx += 1


func check_unlocks() -> void:
	#Unlock a new level
	if level_to_unlock != -1:
		var section = Sections.get_child(section_to_unlock - 1)
		section.disable_level(level_to_unlock)
		await TransitionManager.transition_finished
		section.unlock_level(level_to_unlock)
	#Unlock a new section
	elif section_to_unlock != -1:
		var section = Sections.get_child(section_to_unlock - 1)
		section.disable()
		await TransitionManager.transition_finished
		#Unfocus previous sections
		get_focused_section().unfocus()
		await get_tree().create_timer(.5).timeout
		section.unlock()
	level_to_unlock = -1
	section_to_unlock = -1


func prepare_to_unlock_level(section, level):
	section_to_unlock = section
	level_to_unlock = level


func unlock_section(prev_section):
	level_to_unlock = -1
	section_to_unlock = prev_section + 1


func _on_level_section_enable_focus(pos, my_section):
	level_focused = true
	section_focused = my_section
	enable_focus.emit(pos, my_section)


func _on_level_section_disable_focus():
	disable_focus.emit()
	#Wait a frame to any back button event wont also trigger on level hub
	await get_tree().process_frame
	level_focused = false

func get_focused_section():
	if not level_focused:
		return null
	return Sections.get_child(section_focused - 1)
