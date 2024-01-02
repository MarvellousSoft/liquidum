class_name DailyButton
extends Control

@onready var MainButton: Button = %Button
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
	MainButton.disabled = not unlocked
	TimeLeft.visible = unlocked
	$HBox/VBoxContainer/StreakContainer.visible = unlocked
	NotCompleted.visible = unlocked
	Completed.visible = false
	if unlocked:
		MainButton.tooltip_text = "DAILY_TOOLTIP"
	else:
		MainButton.tooltip_text = "DAILY_TOOLTIP_DISABLED"
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
	if MainButton.disabled:
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
	if size != MainButton.size:
		size = MainButton.size

static func _simple_hints(_rng: RandomNumberGenerator, grid: GridModel) -> void:
	Level.HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid)

static func _simple_boats(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.default(grid.rows(), grid.cols())
	h.total_boats = rng.randf() < 0.5
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() * .75)))
	h.apply_to_grid(grid)

static func _continuity_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	RandomHub._hard_visibility(rng, grid)

static func _hidden_hints(n: int, m: int) -> Callable:
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

static func _fixed_opts(opts: int) -> Callable:
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
static func gen_level(l_gen: RandomLevelGenerator, today: String) -> LevelData:
	var date_dict := Time.get_datetime_dict_from_datetime_string(today, true)
	var weekday: Time.Weekday = date_dict.weekday
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_datetime_string(today)
	var preprocessed_state := FileManager.load_dailies(date_dict.year).success_state(date_dict)
	if preprocessed_state != 0 and false:
		rng.state = preprocessed_state
	var g: GridModel = null
	var strategies := SolverModel.STRATEGY_LIST.keys()
	match weekday:
		Time.WEEKDAY_MONDAY:
			g = await l_gen.generate(rng,7, 7, _simple_hints, _fixed_opts(0), strategies, [])
		Time.WEEKDAY_TUESDAY:
			g = await l_gen.generate(rng, 5, 5, _continuity_hints, _fixed_opts(1), strategies, [])
		Time.WEEKDAY_WEDNESDAY:
			g = await l_gen.generate(rng, 6, 6, _hidden_hints, _fixed_opts(0), strategies, [])
		Time.WEEKDAY_THURSDAY:
			g = await l_gen.generate(rng, 5, 5, _simple_hints, _fixed_opts(1), strategies, [])
		Time.WEEKDAY_FRIDAY:
			g = await l_gen.generate(rng, 7, 7, _simple_boats, _fixed_opts(2), strategies, [], true)
			assert(g._any_sol_boats())
		Time.WEEKDAY_SATURDAY:
			g = await l_gen.generate(rng, 6, 6, _continuity_hints, _fixed_opts(0), strategies, [])
		Time.WEEKDAY_SUNDAY:
			g = await l_gen.generate(rng, 6, 6, _continuity_hints, _fixed_opts(3), strategies, [], true)
	if g != null:
		return LevelData.new(DAY_STR[weekday], "", g.export_data(), "")
	return null

func _on_button_pressed() -> void:
	MainButton.disabled = true
	var today := _today()
	if not FileManager.has_daily_level(today):
		GeneratingLevel.enable()
		var level := await DailyButton.gen_level(gen, today)
		GeneratingLevel.disable()
		if level != null:
			FileManager.save_daily_level(today, level)
	var level_data := FileManager.load_daily_level(today)
	if level_data != null:
		var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), FileManager._daily_basename(today), level_data.full_name, level_data.description, ["daily"])
		level.reset_text = &"CONFIRM_RESET_DAILY"
		level.won.connect(level_completed.bind(level))
		level.reset_mistakes_on_empty = false
		level.reset_mistakes_on_reset = false
		TransitionManager.push_scene(level)
	MainButton.disabled = false

func level_completed(info: Level.WinInfo, level: Level) -> void:
	var l_id := await upload_leaderboard(info)
	var l_data := await get_leaderboard_data(l_id)
	level.display_leaderboard(l_data)
	if info.first_win and SteamManager.stats_received:
		SteamStats.increment_daily_all()
	if not info.first_win:
		return
	var data := UserData.current()
	if info.mistakes < 3:
		if SteamManager.stats_received:
			SteamStats.increment_daily_good()
		if info.mistakes == 0 and SteamManager.stats_received:
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

# 27 hours, enough
const MAX_TIME := 100000

func upload_leaderboard(info: Level.WinInfo) -> int:
	if not SteamManager.enabled:
		return -1
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	var score: int = mini(info.mistakes, 1000) * MAX_TIME + mini(floori(info.time_secs), MAX_TIME - 1)
	Steam.findOrCreateLeaderboard("daily_%s" % date, Steam.LEADERBOARD_SORT_METHOD_ASCENDING, Steam.LEADERBOARD_DISPLAY_TYPE_TIME_SECONDS)
	var ret: Array = await Steam.leaderboard_find_result
	if not ret[1]:
		push_warning("Leaderboard not found for daily %s" % date)
		return -1
	var l_id: int = ret[0]
	Steam.uploadLeaderboardScore(score, true, PackedInt32Array(), l_id)
	ret = await Steam.leaderboard_score_uploaded
	if not ret[0]:
		push_warning("Failed to upload entry for daily %s" % date)
	return l_id

class ListEntry:
	var global_rank: int
	# Name. Might be "10% percentile"
	var text: String
	# Might be null
	var image: Image
	var mistakes: int
	var secs: int
	static func create(data: Dictionary, override_name := "") -> ListEntry:
		var entry := ListEntry.new()
		entry.global_rank = data.global_rank
		entry.mistakes = data.score / MAX_TIME
		entry.secs = data.score % MAX_TIME
		if override_name.is_empty():
			if data.steam_id == Steam.getSteamID():
				entry.text = Steam.getPersonaName()
			else:
				var nickname := Steam.getPlayerNickname(data.steam_id)
				entry.text = Steam.getFriendPersonaName(data.steam_id) if nickname.is_empty() else nickname
			Steam.getPlayerAvatar(Steam.AVATAR_SMALL, data.steam_id)
			var ret: Array = await Steam.avatar_loaded
			entry.image = Image.create_from_data(ret[1], ret[1], false, Image.FORMAT_RGBA8, ret[2])
		else:
			entry.text = override_name
		print("%s %d/%d" % [entry.text, entry.secs, entry.mistakes])
		return entry

class LeaderboardData:
	var list: Array[ListEntry]
	# Only the secs of the top 100 scores that have no mistakes
	# Used to draw an histogram
	var top_no_mistakes: Array[int]

func get_leaderboard_data(l_id: int) -> LeaderboardData:
	if not SteamManager.enabled:
		return null
	var data := LeaderboardData.new()
	var list_has_rank := {}
	Steam.downloadLeaderboardEntries(0, 0, Steam.LEADERBOARD_DATA_REQUEST_FRIENDS, l_id)
	var ret: Array = await Steam.leaderboard_scores_downloaded
	for entry in ret[2]:
		list_has_rank[entry.global_rank] = true
		data.list.append(await ListEntry.create(entry))
	var total := Steam.getLeaderboardEntryCount(l_id)
	Steam.downloadLeaderboardEntries(1, 1000, Steam.LEADERBOARD_DATA_REQUEST_GLOBAL, l_id)
	ret = await Steam.leaderboard_scores_downloaded
	var percentiles := [[0.01, "PCT_1"], [0.1, "PCT_10"], [0.5, "PCT_50"]]
	for entry in ret[2]:
		for pct in percentiles:
			if entry.global_rank == ceili(float(total) * pct[0]) and not list_has_rank.has(entry.global_rank):
				data.list.append(await ListEntry.create(entry, tr(pct[1])))
				list_has_rank[entry.global_rank] = true
		# Only on no mistakes
		if entry.score < MAX_TIME:
			data.top_no_mistakes.append(entry.score)
	for pct in percentiles:
		if not list_has_rank.has(ceili(float(total) * pct[0])):
			# If this happens, we can do extra requests. But are we really that popular?
			push_warning("%.2f percentile not in top entries" % pct[0])
	return data
