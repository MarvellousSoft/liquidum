extends Control

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()

@onready var Sections = $Sections


func _ready():
	update_sections()


func update_sections():
	var idx = 1
	for section in Sections.get_children():
		var unlocked = LevelLister.get_max_unlocked_level(idx)
		if unlocked == 0:
			section.disable()
		else:
			section.enable()
			section.setup(idx, unlocked)
		idx += 1


func _on_level_section_enable_focus(pos, my_section):
	enable_focus.emit(pos, my_section)


func _on_level_section_disable_focus():
	disable_focus.emit()
