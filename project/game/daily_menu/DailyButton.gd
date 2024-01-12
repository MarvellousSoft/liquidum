class_name DailyButton
extends Control

# 27 hours, enough
const MAX_TIME := 100000

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
	deadline -= Time.get_time_zone_from_system().bias * 60
	
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
		return SteamManager.steam.getServerRealTime()
	return int(Time.get_unix_time_from_system())

func _today(dt: int = 0) -> String:
	var tz := Time.get_time_zone_from_system()
	var today := Time.get_datetime_string_from_unix_time(_unixtime() - dt + int(tz.bias) * 60)
	return today.substr(0, today.find('T'))

func _yesterday() -> String:
	return _today(24 * 60 * 60)

func _on_timer_timeout():
	_update_time_left()

func _process(_dt: float) -> void:
	if size != MainButton.size:
		size = MainButton.size

const DAY_STR := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

static func _level_name(weekday: Time.Weekday) -> String:
	return "%s_LEVEL" % DAY_STR[weekday]

static func _level_desc(weekday: Time.Weekday) -> String:
	return "%s_LEVEL_DESC" % DAY_STR[weekday]

static func gen_level(l_gen: RandomLevelGenerator, today: String) -> LevelData:
	var date_dict := Time.get_datetime_dict_from_datetime_string(today, true)
	var weekday: Time.Weekday = date_dict.weekday
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash(today)
	var preprocessed_state := FileManager.load_dailies(date_dict.year).success_state(date_dict)
	if preprocessed_state != 0:
		rng.state = preprocessed_state
	var g: GridModel = await RandomFlavors.gen(l_gen, rng, weekday as RandomFlavors.Flavor)
	if g != null:
		return LevelData.new(_level_name(weekday), _level_desc(weekday), g.export_data(), "")
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

func upload_leaderboard(info: Level.WinInfo) -> int:
	if not SteamManager.enabled:
		return -1
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	var score: int = mini(info.mistakes, 1000) * MAX_TIME + mini(floori(info.time_secs), MAX_TIME - 1)
	SteamManager.steam.findOrCreateLeaderboard("daily_%s" % date, SteamManager.steam.LEADERBOARD_SORT_METHOD_ASCENDING, SteamManager.steam.LEADERBOARD_DISPLAY_TYPE_TIME_SECONDS)
	var ret: Array = await SteamManager.steam.leaderboard_find_result
	if not ret[1]:
		push_warning("Leaderboard not found for daily %s" % date)
		return -1
	var l_id: int = ret[0]
	SteamManager.steam.uploadLeaderboardScore(score, true, PackedInt32Array(), l_id)
	ret = await SteamManager.steam.leaderboard_score_uploaded
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
			if data.steam_id == SteamManager.steam.getSteamID():
				entry.text = SteamManager.steam.getPersonaName()
			else:
				var nickname: String = SteamManager.steam.getPlayerNickname(data.steam_id)
				entry.text = SteamManager.steam.getFriendPersonaName(data.steam_id) if nickname.is_empty() else nickname
			SteamManager.steam.getPlayerAvatar(SteamManager.steam.AVATAR_SMALL, data.steam_id)
			var ret: Array = await SteamManager.steam.avatar_loaded
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
	SteamManager.steam.downloadLeaderboardEntries(0, 0, SteamManager.steam.LEADERBOARD_DATA_REQUEST_FRIENDS, l_id)
	var ret: Array = await SteamManager.steam.leaderboard_scores_downloaded
	for entry in ret[2]:
		list_has_rank[entry.global_rank] = true
		data.list.append(await ListEntry.create(entry))
	var total: int = SteamManager.steam.getLeaderboardEntryCount(l_id)
	SteamManager.steam.downloadLeaderboardEntries(1, 1000, SteamManager.steam.LEADERBOARD_DATA_REQUEST_GLOBAL, l_id)
	ret = await SteamManager.steam.leaderboard_scores_downloaded
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
