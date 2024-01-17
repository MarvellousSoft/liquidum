extends Control

@onready var Grid: GridContainer = %Grid

func display(data: DailyButton.LeaderboardData) -> void:
	# Leave the first five for copying so we don't need to programatically set stuff
	while Grid.get_child_count() > 10:
		var c := Grid.get_child(Grid.get_child_count() - 1)
		Grid.remove_child(c)
		c.queue_free()
	for item in data.list:
		var icon := Grid.get_node("Icon1").duplicate()
		if item.image != null:
			icon.texture = ImageTexture.create_from_image(item.image)
		var pos := Grid.get_node("Pos1").duplicate()
		pos.text = "%d." % item.global_rank
		var name_ := Grid.get_node("Name1").duplicate()
		name_.text = item.text
		var mistakes := Grid.get_node("Mistakes1").duplicate()
		mistakes.text = str(item.mistakes)
		var time := Grid.get_node("Time1").duplicate()
		time.text = Level.time_str(item.secs)
		for c in [icon, pos, name_, mistakes, time]:
			c.show()
			Grid.add_child(c)
	for c in ["Icon1", "Pos1", "Name1", "Mistakes1", "Time1"]:
		Grid.get_node(c).hide()
