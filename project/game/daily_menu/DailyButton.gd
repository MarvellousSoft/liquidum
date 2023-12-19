extends Control

@onready var DailyButton: Button = %Button
@onready var TimeLeft: Label = %TimeLeft
@onready var OngoingSolution = %OngoingSolution
@onready var Completed = %Completed
@onready var NotCompleted = %NotCompleted
@onready var CurStreak = %CurStreak
@onready var BestStreak = %BestStreak

var date: String
var deadline: int
var gen := RandomLevelGenerator.new()

func _ready() -> void:
	Global.dev_mode_toggled.connect(func(_on): _update())

func _enter_tree() -> void:
	call_deferred("_update")

func _update() -> void:
	var unlocked := Global.is_dev_mode() or LevelLister.section_complete(4)
	DailyButton.disabled = not unlocked
	TimeLeft.visible = unlocked
	$HBox/VBoxContainer/StreakContainer.visible = unlocked
	NotCompleted.visible = unlocked
	if unlocked:
		DailyButton.tooltip_text = "DAILY_TOOLTIP"
	else:
		DailyButton.tooltip_text = "DAILY_TOOLTIP_DISABLED"
		OngoingSolution.visible = false
		return

	date = _today()
	deadline = int(Time.get_unix_time_from_datetime_string(date + "T23:59:59"))
	
	if FileManager.has_daily_level(date):
		var save := FileManager.load_level(FileManager._daily_basename(date))
		if save:
			OngoingSolution.visible = not save.is_solution_empty()
			Completed.visible = save.is_completed()
			NotCompleted.visible = not save.is_completed()
	_update_time_left()
	_update_streak()

func _update_time_left() -> void:
	if DailyButton.disabled:
		return
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
		txt = tr(txt).format({"s": "s" if num > 1 else ""})
		TimeLeft.text = "%s %s" % [TextServerManager.get_primary_interface().format_number(str(num)), txt]
	else:
		_update()


func _update_streak() -> void:
	var data := UserData.current()
	if data.current_streak > 0 and data.last_day < _yesterday():
		data.current_streak = 0
		UserData.save()
	CurStreak.text = tr("CUR_STREAK") % data.current_streak
	BestStreak.text = tr("BEST_STREAK") % data.best_streak


func _unixtime() -> int:
	if SteamManager.enabled:
		return Steam.getServerRealTime()
	return int(Time.get_unix_time_from_system())

func _today(dt: int = 0) -> String:
	var today := Time.get_datetime_string_from_unix_time(_unixtime() - dt)
	return today.substr(0, today.find('T'))

func _yesterday() -> String:
	return _today(24 * 60 * 60)

func _on_timer_timeout():
	_update_time_left()

func _process(_dt: float) -> void:
	if size != DailyButton.size:
		size = DailyButton.size

func _simple_hints(n: int, m: int) -> Callable:
	return func(_rng: RandomNumberGenerator) -> Level.HintVisibility:
		return Level.HintVisibility.default(n, m)

func _simple_boats(n: int, m: int) -> Callable:
	return func(rng: RandomNumberGenerator) -> Level.HintVisibility:
		var h := Level.HintVisibility.default(n, m)
		h.total_boats = rng.randf() < 0.5
		for a in [h.row, h.col]:
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() * .75)))
		return h

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
func gen_level(today: String) -> LevelData:
	var weekday: Time.Weekday = Time.get_datetime_dict_from_datetime_string(today, true).weekday
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_datetime_string(today)
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
			g = await gen.generate(rng, _simple_boats(7, 7), _fixed_opts(2), strategies, [], true)
			assert(g._any_sol_boats())
		Time.WEEKDAY_SATURDAY:
			g = await gen.generate(rng, _continuity_hints(6, 6), _fixed_opts(0), strategies, [])
		Time.WEEKDAY_SUNDAY:
			g = await gen.generate(rng, _continuity_hints(6, 6), _fixed_opts(3), strategies, [], true)
	if g != null:
		return LevelData.new(DAY_STR[weekday], "", g.export_data(), "")
	return null

func _on_button_pressed() -> void:
	DailyButton.disabled = true
	var today := _today()
	if not FileManager.has_daily_level(today):
		GeneratingLevel.enable()
		var level := await gen_level(today)
		GeneratingLevel.disable()
		if level != null:
			FileManager.save_daily_level(today, level)
	var level_data := FileManager.load_daily_level(today)
	if level_data != null:
		var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), FileManager._daily_basename(today), level_data.full_name, level_data.description, ["daily"])
		level.reset_text = &"CONFIRM_RESET_DAILY"
		level.won.connect(level_completed)
		TransitionManager.push_scene(level)
	DailyButton.disabled = false

func level_completed(mistakes: int, first_try_no_resets: bool, first_win: bool) -> void:
	if first_win and SteamManager.stats_received:
		SteamStats.increment_daily_all()
	if not first_try_no_resets or not first_win:
		return
	var data := UserData.current()
	if mistakes < 3:
		if SteamManager.stats_received:
			SteamStats.increment_daily_good()
		if mistakes == 0 and SteamManager.stats_received:
			SteamStats.unlock_daily_no_mistakes()
		# It the streak was broken this would be handled in _update_streak
		if date != data.last_day:
			data.last_day = date
			data.current_streak += 1
			data.best_streak = max(data.best_streak, data.current_streak)
			UserData.save()
	else:
		if data.current_streak > 0:
			data.current_streak = 0
			UserData.save()
	
