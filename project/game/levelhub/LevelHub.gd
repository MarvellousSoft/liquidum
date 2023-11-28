extends Control

signal enable_focus(pos : Vector2, my_session : int)
signal disable_focus()

@onready var Sessions = $Sessions


func _ready():
	update_sessions()


func update_sessions():
	var idx = 1
	for session in Sessions.get_children():
		var unlocked = LevelLister.get_max_unlocked_level(idx)
		if unlocked == 0:
			session.disable()
		else:
			session.enable()
			session.setup(idx, unlocked)
		idx += 1


func _on_level_session_enable_focus(pos, my_session):
	enable_focus.emit(pos, my_session)


func _on_level_session_disable_focus():
	disable_focus.emit()
