class_name SingleDayLeaderboard
extends ScrollContainer

@onready var Grid: GridContainer = %Grid

func _ready() -> void:
	# Leave the first five for copying so we don't need to programatically set stuff
	while Grid.get_child_count() > 10:
		var c := Grid.get_child(Grid.get_child_count() - 1)
		Grid.remove_child(c)
		c.queue_free()
	for c in ["Icon1", "Pos1", "NameContainer1", "Mistakes1", "Time1"]:
		Grid.get_node(c).hide()


func display_day(data: RecurringMarathon.LeaderboardData, date: String) -> void:
	Grid.get_node("Date").text = date
	for item in data.list:
		var icon := Grid.get_node("Icon1").duplicate()
		if item.image != null:
			icon.texture = ImageTexture.create_from_image(item.image)
		var pos := Grid.get_node("Pos1").duplicate()
		pos.text = "%d." % item.global_rank
		var name_ := Grid.get_node("NameContainer1").duplicate()
		name_.get_node("Name").text = item.text
		var flair: Label = name_.get_node("Flair")
		flair.visible = item.flair != null
		if item.flair != null:
			var sflair := FlairManager.create_flair(item.flair.id)
			flair.tooltip_text = sflair.description
			flair.text = " %s " % [sflair.text]
			flair.add_theme_color_override("font_color", sflair.color)
			var contrast_color := Global.get_contrast_background(sflair.color)
			contrast_color.a = 0.75
			flair.get_node("BG").modulate = contrast_color
			var plus: Label = flair.get_node("Plus")
			plus.visible = item.flair.extra_flairs > 0
			plus.text = "+%d" % [item.flair.extra_flairs]
		var mistakes := Grid.get_node("Mistakes1").duplicate()
		mistakes.text = str(item.mistakes)
		var time := Grid.get_node("Time1").duplicate()
		time.text = Level.time_str(item.secs)
		for c in [icon, pos, name_, mistakes, time]:
			c.show()
			Grid.add_child(c)
	update_theme(Profile.get_option("dark_mode"))

func update_theme(_dark_mode: bool) -> void:
	pass
