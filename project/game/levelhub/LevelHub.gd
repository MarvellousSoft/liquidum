extends Control

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()

@onready var Sections = $Sections

var level_focused := false
var level_to_unlock = -1
var section_to_unlock = -1

func _ready():
	update_sections()


func _enter_tree():
	check_unlocks()


func update_sections():
	var idx = 1
	for section in Sections.get_children():
		section.set_number(idx)
		var unlocked = LevelLister.get_max_unlocked_level(idx)
		if unlocked == 0:
			section.disable()
		else:
			section.enable()
			section.setup(self, idx, unlocked)
		idx += 1


func check_unlocks() -> void:
	if level_to_unlock != -1:
		pass
	elif section_to_unlock != -1:
		pass
	level_to_unlock = -1
	section_to_unlock = -1

func unlock_level(level, section):
	level_to_unlock = level
	section_to_unlock = section


func unlock_section(section):
	level_to_unlock = -1
	section_to_unlock = section


func _on_level_section_enable_focus(pos, my_section):
	level_focused = true
	enable_focus.emit(pos, my_section)


func _on_level_section_disable_focus():
	disable_focus.emit()
	#Wait a frame to any back button event wont also trigger on level hub
	await get_tree().process_frame
	level_focused = false
