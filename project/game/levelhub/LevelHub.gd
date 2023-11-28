extends Control


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
			session.setup(unlocked)
		idx += 1
