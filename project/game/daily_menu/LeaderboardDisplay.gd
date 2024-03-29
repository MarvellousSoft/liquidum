class_name LeaderboardDisplay
extends Control

# Ex. DAILY
@export var tr_name: String
@export var has_prev: bool = true
# Link to specific speed run to be used as speedrun.com/Liquidum?x=KEY
@export var speedrun_key: String = ""

@onready var Leaderboards: TabContainer = %TabContainer

static func get_or_create(level: Level, tr_name_: String, has_prev_: bool, speedrun_key_ := "") -> LeaderboardDisplay:
	if not level.has_node("LeaderboardDisplay"):
		var d: LeaderboardDisplay = load("res://game/daily_menu/LeaderboardDisplay.tscn").instantiate()
		d.tr_name = tr_name_
		d.has_prev = has_prev_
		d.speedrun_key = speedrun_key_
		d.modulate.a = 0
		d.visible = not Global.is_dev_mode()
		level.add_leaderboard_display(d)
		level.create_tween().tween_property(d, "modulate:a", 1, 1)
	return level.get_node("LeaderboardDisplay")

func _single(s_name: String) -> SingleDayLeaderboard:
	var obj: SingleDayLeaderboard = load(^"res://game/daily_menu/SingleDayLeaderboard.tscn").instantiate()
	obj.name = s_name
	return obj

func _ready() -> void:
	Profile.dark_mode_toggled.connect(_update_theme)
	_update_theme(Profile.get_option("dark_mode"))
	assert(tr_name != "")
	%SpeedrunButton.visible = speedrun_key != ""
	var curr := tr("%s_CURR" % [tr_name])
	Leaderboards.add_child(_single("%s (%s)" % [curr, tr("ALL")]))
	Leaderboards.add_child(_single("%s (%s)" % [curr, tr("FRIENDS")]))
	if has_prev:
		var prev := tr("%s_PREV" % [tr_name])
		Leaderboards.add_child(_single("%s (%s)" % [prev, tr("ALL")]))
		Leaderboards.add_child(_single("%s (%s)" % [prev, tr("FRIENDS")]))

func display(current_data: Array[RecurringMarathon.LeaderboardData], current_date: String, previous: Array[RecurringMarathon.LeaderboardData], previous_date: String) -> void:
	if current_data.size() >= 1:
		Leaderboards.get_child(0).display_day(current_data[0], current_date)
	if current_data.size() >= 2:
		Leaderboards.get_child(1).display_day(current_data[1], current_date)
	if has_prev:
		if previous.size() >= 1:
			Leaderboards.get_child(2).display_day(previous[0], previous_date)
		if previous.size() >= 2:
			Leaderboards.get_child(3).display_day(previous[1], previous_date)
	else:
		assert(previous.is_empty())

func show_current_all() -> void:
	Leaderboards.current_tab = 0

func _update_theme(dark_mode: bool) -> void:
	theme = Global.get_font_theme(dark_mode)
	for tab in Leaderboards.get_children():
		tab.update_theme(dark_mode)

func _on_button_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")

func _on_speedrun_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	SteamManager.overlay_or_browser("https://www.speedrun.com/Liquidum?x=%s" % [speedrun_key])
