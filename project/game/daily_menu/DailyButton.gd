extends Control

@onready var DailyButton: Button = $HBox/Button
@onready var TimeLeft: Label = $HBox/TimeLeft
var deadline: int
var gen := RandomLevelGenerator.new()

func _enter_tree() -> void:
	call_deferred("_update")

func _update() -> void:
	var date := _today()
	deadline = int(Time.get_unix_time_from_datetime_string(date + "T23:59:59"))
	
	if FileManager.has_daily_level(date):
		var save := FileManager.load_level(FileManager._daily_basename(date))
		if save.is_completed():
			DailyButton.text = "DAILY_COMPLETED"
		else:
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

func _simple_hints(n: int, m: int) -> Callable:
	return func(_rng: RandomNumberGenerator) -> Level.HintVisibility:
		return Level.HintVisibility.default(n, m)

func _continuity_hints(n: int, m: int) -> Callable:
	return RandomHub._hard_visibility(n, m)

func _hidden_hints(n: int, m: int) -> Callable:
	return func(rng: RandomNumberGenerator) -> Level.HintVisibility:
		var h := Level.HintVisibility.new()
		h.total_water = rng.randf() < 0.5
		for i in n:
			h.row.append(0)
		for j in m:
			h.col.append(0)
		for a in [h.row, h.col]:
			RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, a.size() - 1))
		return h

func _fixed_opts(opts: int) -> Callable:
	return func(_rng: RandomNumberGenerator) -> int:
		return opts

const DAY_STR := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

# Monday - Simple, basic hints, larger
# Tuesday - Diagonals, together/separate
# Wednesday - Simple, hidden hints
# Thursday - Diagonals, basic hints
# Friday - Simple, boats
# Saturday - Simple, together/separate
# Sunday - Diagonals, boats
func gen_level(date: String) -> LevelData:
	var weekday: Time.Weekday = Time.get_datetime_dict_from_datetime_string(date, true).weekday
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_datetime_string(date)
	var g: GridModel = null
	var strategies := SolverModel.STRATEGY_LIST.keys()
	match weekday:
		Time.WEEKDAY_MONDAY:
			g = await gen.generate(rng, _simple_hints(7, 7), _fixed_opts(0), strategies, [])
		Time.WEEKDAY_TUESDAY:
			g = await gen.generate(rng, _continuity_hints(5, 5), _fixed_opts(1), strategies, [])
		Time.WEEKDAY_WEDNESDAY:
			g = await gen.generate(rng, _hidden_hints(6, 6), _fixed_opts(0), strategies, [])
		Time.WEEKDAY_THURSDAY:
			g = await gen.generate(rng, _simple_hints(5, 5), _fixed_opts(1), strategies, [])
		Time.WEEKDAY_FRIDAY:
			g = await gen.generate(rng, _simple_hints(7, 7), _fixed_opts(2), strategies, [])
		Time.WEEKDAY_SATURDAY:
			g = await gen.generate(rng, _continuity_hints(6, 6), _fixed_opts(0), strategies, [])
		Time.WEEKDAY_SUNDAY:
			g = await gen.generate(rng, _continuity_hints(6, 6), _fixed_opts(3), strategies, [])
	if g != null:
		return LevelData.new(DAY_STR[weekday], "", g.export_data(), "")
	return null

func _on_button_pressed() -> void:
	DailyButton.disabled = true
	var date := _today()
	if not FileManager.has_daily_level(date):
		var level := await gen_level(date)
		if level != null:
			FileManager.save_daily_level(date, level)
	var level_data := FileManager.load_daily_level(date)
	if level_data != null:
		var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), FileManager._daily_basename(date), level_data.full_name, level_data.description)
		TransitionManager.push_scene(level)
	DailyButton.disabled = false
