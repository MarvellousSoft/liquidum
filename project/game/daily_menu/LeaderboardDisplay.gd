class_name LeaderboardDisplay
extends Control

func _ready() -> void:
	Profile.dark_mode_toggled.connect(_update_theme)
	_update_theme(Profile.get_option("dark_mode"))
	# This is to prevent a Godot bug, I believe. When I add a theme override, it recalculates the
	# sizes and positions of stuff and fixes the position of the TabBar, which is initially wrong
	# for some reason.
	await get_tree().process_frame
	%TabContainer.add_theme_font_size_override("fake", 30)

func _display_day(node: Node, data: DailyButton.LeaderboardData, date: String) -> void:
	var Grid: GridContainer = node.get_node(^"%Grid")
	# Leave the first five for copying so we don't need to programatically set stuff
	while Grid.get_child_count() > 10:
		var c := Grid.get_child(Grid.get_child_count() - 1)
		Grid.remove_child(c)
		c.queue_free()
	Grid.get_node("Date").text = date
	for item in data.list:
		var icon := Grid.get_node("Icon1").duplicate()
		if item.image != null:
			icon.texture = ImageTexture.create_from_image(item.image)
		var pos := Grid.get_node("Pos1").duplicate()
		pos.text = "%d." % item.global_rank
		var name_ := Grid.get_node("NameContainer1").duplicate()
		name_.get_node("Name").text = item.text
		name_.get_node("Dev").visible = item.is_dev
		var mistakes := Grid.get_node("Mistakes1").duplicate()
		mistakes.text = str(item.mistakes)
		var time := Grid.get_node("Time1").duplicate()
		time.text = Level.time_str(item.secs)
		for c in [icon, pos, name_, mistakes, time]:
			c.show()
			Grid.add_child(c)
	for c in ["Icon1", "Pos1", "NameContainer1", "Mistakes1", "Time1"]:
		Grid.get_node(c).hide()

func display(today: Array[DailyButton.LeaderboardData], today_date: String, yesterday: Array[DailyButton.LeaderboardData], yesterday_date: String) -> void:
	if today.size() >= 1:
		_display_day(%TODAY_ALL, today[0], today_date)
	if today.size() >= 2:
		_display_day(%TODAY_FRIENDS, today[1], today_date)
	if yesterday.size() >= 1:
		_display_day(%YESTERDAY_ALL, yesterday[0], yesterday_date)
	if yesterday.size() >= 2:
		_display_day(%YESTERDAY_FRIENDS, yesterday[1], yesterday_date)

func show_today_all() -> void:
	%TabContainer.current_tab = 0

func _update_theme(dark_mode: bool) -> void:
	theme = Global.get_font_theme(dark_mode)
