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

func display(today: Array[RecurringMarathon.LeaderboardData], today_date: String, yesterday: Array[RecurringMarathon.LeaderboardData], yesterday_date: String) -> void:
	if today.size() >= 1:
		%TODAY_ALL.display_day(today[0], today_date)
	if today.size() >= 2:
		%TODAY_FRIENDS.display_day(today[1], today_date)
	if yesterday.size() >= 1:
		%YESTERDAY_ALL.display_day(yesterday[0], yesterday_date)
	if yesterday.size() >= 2:
		%YESTERDAY_FRIENDS.display_day(yesterday[1], yesterday_date)

func show_today_all() -> void:
	%TabContainer.current_tab = 0

func _update_theme(dark_mode: bool) -> void:
	theme = Global.get_font_theme(dark_mode)
	for tab in %TabContainer.get_children():
		tab.update_theme(dark_mode)
