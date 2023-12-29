extends Control

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()

@onready var Sections = $Sections

var level_focused := false
var level_to_unlock = -1
var section_to_unlock = -1

func _ready() -> void:
	update_sections()



func _enter_tree() -> void:
	Global.dev_mode_toggled.connect(_on_dev_mode)
	check_unlocks()

func _exit_tree() -> void:
	Global.dev_mode_toggled.disconnect(_on_dev_mode)

func _on_dev_mode(_on: bool) -> void:
	update_sections()

func update_sections() -> void:
	var idx = 1
	for section in Sections.get_children():
		section.set_number(idx)
		var unlocked := LevelLister.get_max_unlocked_level(idx)
		if Global.is_dev_mode():
			unlocked = LevelLister.count_section_levels(idx)
		if unlocked == 0:
			section.disable()
		else:
			section.enable()
			section.setup(self, idx, unlocked)
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
		Sections.get_child(section_to_unlock - 2).unfocus()
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
	enable_focus.emit(pos, my_section)


func _on_level_section_disable_focus():
	disable_focus.emit()
	#Wait a frame to any back button event wont also trigger on level hub
	await get_tree().process_frame
	level_focused = false
