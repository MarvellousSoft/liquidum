extends Control

@onready var DailyButton: Button = $HBox/Button
@onready var TimeLeft: Label = $HBox/TimeLeft
var deadline: int

func _enter_tree() -> void:
	call_deferred("_update")

func _update() -> void:
	var date := _today()
	deadline = int(Time.get_unix_time_from_datetime_string(date + "T23:59:59"))
	
	if FileManager.has_daily_level(date):
		DailyButton.text = "DAILY_CONTINUE"
	else:
		DailyButton.text = "DAILY_START"
	_update_time_left()

func _update_time_left() -> void:
	var secs_left := deadline - _unixtime()
	if secs_left > 0:
		var num: int
		var txt: String
		if secs_left >= 3600:
			num = secs_left / 3600
			txt = "HOURS_LEFT"
		else:
			num = secs_left / 60
			txt = "MINUTES_LEFT"
		TimeLeft.text = "%s %s" % [TextServerManager.get_primary_interface().format_number(str(num)), tr(txt)]
	else:
		_update()


func _unixtime() -> int:
	if SteamManager.enabled:
		return Steam.getServerRealTime()
	return int(Time.get_unix_time_from_system())

func _today() -> String:
	var date := Time.get_datetime_string_from_unix_time(_unixtime())
	return date.substr(0, date.find('T'))


func _on_timer_timeout():
	_update_time_left()

func _process(_dt: float) -> void:
	if size != DailyButton.size:
		size = DailyButton.size

# Monday - Simple, all basic hints
# Tuesday - Simple, hidden hints
# Wednesday - Simple, together/separate
# Thursday - Diagonals, basic hints
# Friday - Diagonals, together/separate
# Saturday - Simple, boats
# Sunday - Diagonals, boats

func gen_level() -> LevelData:
	# TODO: generate
	return null

func _on_button_pressed() -> void:
	DailyButton.disabled = true
	var date := _today()
	if not FileManager.has_daily_level(date):
		var level := await gen_level()
		FileManager.save_daily_level(date, level)
	var level_data := FileManager.load_daily_level(date)
	var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), "daily_%s" % date, level_data.full_name, level_data.description)
	TransitionManager.push_scene(level)
	DailyButton.disabled = false
