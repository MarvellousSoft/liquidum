class_name DailyButton
extends Control

# 27 hours, enough
const MAX_TIME := 100000
const DAY_STR := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

const DEV_IDS := {76561198046896163: true, 76561198046336325: true}

@onready var MainButton: Button = %Button
@onready var TimeLeft: Label = %TimeLeft
@onready var OngoingSolution = %OngoingSolution
@onready var Completed = %Completed
@onready var NotCompleted = %NotCompleted
@onready var CurStreak = %CurStreak
@onready var BestStreak = %BestStreak

var date: String
var yesterday: String
var deadline: int
var gen := RandomLevelGenerator.new()
var already_uploaded_today := false

func _ready() -> void:
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	Global.dev_mode_toggled.connect(func(_on): _update())


func _enter_tree() -> void:
	call_deferred("_update")


func _process(_dt: float) -> void:
	if size != MainButton.size:
		size = MainButton.size


func _update() -> void:
	var unlocked := Global.is_dev_mode() or CampaignLevelLister.section_complete(4)
	if unlocked and Profile.get_option("daily_notification") == Profile.DailyStatus.NotUnlocked:
		if NotificationManager.enabled:
			if NotificationManager.permission_granted():
				Profile.set_option("daily_notification", Profile.DailyStatus.Enabled)
				NotificationManager.do_add_daily_notif()
			elif ConfirmationScreen.start_confirmation("CONFIRMATION_DAILY_NOTIF"):
				if await ConfirmationScreen.pressed:
					Profile.set_option("daily_notification", Profile.DailyStatus.Enabled)
					Profile.daily_notification_changed.emit(true)
				else:
					Profile.set_option("daily_notification", Profile.DailyStatus.Disabled)
	MainButton.disabled = not unlocked
	TimeLeft.visible = unlocked
	%StreakContainer.visible = unlocked
	NotCompleted.visible = unlocked
	Completed.visible = false
	OngoingSolution.visible = false
	if Global.is_mobile:
		%DailyUnlockText.visible = not unlocked
		# Looks better
		%DailyHBox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if unlocked else Control.SIZE_SHRINK_CENTER
	if unlocked:
		MainButton.tooltip_text = "DAILY_TOOLTIP"
	else:
		MainButton.tooltip_text = "DAILY_TOOLTIP_DISABLED"
		OngoingSolution.visible = false
		return

	date = DailyButton._today()
	yesterday = DailyButton._yesterday()
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
	var secs_left := deadline - DailyButton._unixtime()
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
	if data.current_streak > 0 and data.last_day < yesterday:
		data.current_streak = 0
		UserData.save()
	CurStreak.text = str(data.current_streak)
	BestStreak.text = str(data.best_streak)


static func _unixtime() -> int:
	if SteamManager.enabled:
		return SteamManager.steam.getServerRealTime()
	return int(Time.get_unix_time_from_system())


static func _unixtime_ok_timezone() -> int:
	var tz := Time.get_time_zone_from_system()
	return _unixtime() + int(tz.bias) * 60


static func _today(dt: int = 0) -> String:
	var today := Time.get_datetime_string_from_unix_time(_unixtime_ok_timezone() - dt)
	return today.substr(0, today.find('T'))


static func _yesterday() -> String:
	return _today(24 * 60 * 60)


func _on_timer_timeout():
	_update_time_left()


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
	if preprocessed_state != 0:
		assert(preprocessed_state == l_gen.success_state)
	if g != null:
		return LevelData.new(_level_name(weekday), _level_desc(weekday), g.export_data(), "")
	return null


func _on_button_pressed() -> void:
	# Update date if needed
	_update_time_left()
	MainButton.disabled = true
	var today := DailyButton._today()
	if not FileManager.has_daily_level(today):
		GeneratingLevel.enable()
		var level := await DailyButton.gen_level(gen, today)
		GeneratingLevel.disable()
		if level != null:
			FileManager.save_daily_level(today, level)
	var level_data := FileManager.load_daily_level(today)
	already_uploaded_today = false
	if level_data != null:
		var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), FileManager._daily_basename(today), level_data.full_name, level_data.description, ["daily2"])
		level.reset_text = &"CONFIRM_RESET_DAILY"
		level.won.connect(level_completed.bind(level))
		level.reset_mistakes_on_empty = false
		level.reset_mistakes_on_reset = false
		TransitionManager.push_scene(level)
		await level.ready
		if SteamManager.enabled:
			var l_id := await get_leaderboard(date)
			var l_data := await get_leaderboard_data(l_id)
			if l_data[0].has_self:
				already_uploaded_today = true
			l_id = await get_leaderboard(yesterday)
			var y_data := await get_leaderboard_data(l_id)
			display_leaderboard(l_data, y_data, level)

	MainButton.disabled = false


func level_completed(info: Level.WinInfo, level: Level) -> void:
	level.get_node("%ShareButton").visible = true
	if SteamManager.enabled:
		var l_id := await get_leaderboard(date)
		if not already_uploaded_today:
			await upload_leaderboard(l_id, info)
		var l_data := await get_leaderboard_data(l_id)
		display_leaderboard(l_data, [], level)
	if not info.first_win:
		return
	if SteamManager.stats_received:
		SteamStats.increment_daily_all()
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


func get_leaderboard(for_date: String) -> int:
	if not SteamManager.enabled:
		return -1
	SteamManager.steam.findOrCreateLeaderboard("daily_%s" % for_date, SteamManager.steam.LEADERBOARD_SORT_METHOD_ASCENDING, SteamManager.steam.LEADERBOARD_DISPLAY_TYPE_TIME_SECONDS)
	var ret: Array = await SteamManager.steam.leaderboard_find_result
	if not ret[1]:
		push_warning("Leaderboard not found for daily %s" % for_date)
		return -1
	return ret[0]


func upload_leaderboard(l_id: int, info: Level.WinInfo) -> void:
	if not SteamManager.enabled:
		return
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	var score: int = mini(info.mistakes, 1000) * MAX_TIME + mini(floori(info.time_secs), MAX_TIME - 1)
	SteamManager.steam.uploadLeaderboardScore(score, true, PackedInt32Array(), l_id)
	var ret: Array = await SteamManager.steam.leaderboard_score_uploaded
	if not ret[0]:
		push_warning("Failed to upload entry for daily %s" % date)


class ListEntry:
	var global_rank: int
	# Name. Might be "10% percentile"
	var text: String
	# Might be null
	var image: Image
	var mistakes: int
	var secs: int
	var is_dev: bool
	static func create(data: Dictionary, override_name := "") -> ListEntry:
		var entry := ListEntry.new()
		entry.global_rank = data.global_rank
		entry.mistakes = data.score / MAX_TIME
		entry.secs = data.score % MAX_TIME
		entry.is_dev = DEV_IDS.has(data.steam_id)
		if override_name.is_empty():
			if data.steam_id == SteamManager.steam.getSteamID():
				entry.text = SteamManager.steam.getPersonaName()
			else:
				var nickname: String = SteamManager.steam.getPlayerNickname(data.steam_id)
				entry.text = SteamManager.steam.getFriendPersonaName(data.steam_id) if nickname.is_empty() else nickname
			SteamManager.steam.getPlayerAvatar(SteamManager.steam.AVATAR_LARGE, data.steam_id)
			var ret: Array = await SteamManager.steam.avatar_loaded
			entry.image = Image.create_from_data(ret[1], ret[1], false, Image.FORMAT_RGBA8, ret[2])
			entry.image.generate_mipmaps()
		else:
			entry.text = override_name
		return entry

class LeaderboardData:
	# Is this user present on list?
	var has_self: bool = false
	# List of friends and percentiles
	var list: Array[ListEntry]
	# Only the secs of the top 1000 scores that have no mistakes
	# Used to draw an histogram
	var top_no_mistakes: Array[int]
	func is_empty() -> bool:
		return list.is_empty()
	func sort() -> void:
		list.sort_custom(func(entry_a: ListEntry, entry_b: ListEntry) -> bool: return entry_a.global_rank < entry_b.global_rank)


func get_leaderboard_data(l_id: int) -> Array[LeaderboardData]:
	var data_all := LeaderboardData.new()
	var data_friends := LeaderboardData.new()
	if not SteamManager.enabled:
		return [data_all, data_friends]
	var total: int = SteamManager.steam.getLeaderboardEntryCount(l_id)
	if total == 0:
		return [data_all, data_friends]
	var list_has_rank := {}
	SteamManager.steam.downloadLeaderboardEntries(0, 0, SteamManager.steam.LEADERBOARD_DATA_REQUEST_FRIENDS, l_id)
	var ret: Array = await SteamManager.steam.leaderboard_scores_downloaded
	for entry in ret[2]:
		list_has_rank[entry.global_rank] = true
		if entry.steam_id == SteamManager.steam.getSteamID():
			data_all.has_self = true
			data_friends.has_self = true
		var l_entry := await ListEntry.create(entry)
		data_all.list.append(l_entry)
		data_friends.list.append(l_entry)
	SteamManager.steam.downloadLeaderboardEntries(1, 1000, SteamManager.steam.LEADERBOARD_DATA_REQUEST_GLOBAL, l_id)
	ret = await SteamManager.steam.leaderboard_scores_downloaded
	var percentiles := [[0.01, "PCT_1"], [0.1, "PCT_10"], [0.5, "PCT_50"]]
	for entry in ret[2]:
		var l_entry: ListEntry = null
		# Tweak this if we get too many users
		if not list_has_rank.has(entry.global_rank) and entry.global_rank < 100:
			l_entry = await ListEntry.create(entry)
			data_all.list.append(l_entry)
		for dev_id in DEV_IDS:
			if entry.steam_id == dev_id and not list_has_rank.has(entry.global_rank):
				if l_entry == null:
					l_entry = await ListEntry.create(entry)
				data_friends.list.append(l_entry)
				list_has_rank[entry.global_rank] = true
		for pct in percentiles:
			if entry.global_rank == ceili(float(total) * pct[0]) and not list_has_rank.has(entry.global_rank):
				# Create again because we're using a custom name for percentiles
				data_friends.list.append(await ListEntry.create(entry, tr(pct[1])))
				list_has_rank[entry.global_rank] = true
		# Only on no mistakes
		if entry.score < MAX_TIME:
			data_all.top_no_mistakes.append(entry.score)
	for pct in percentiles:
		if not list_has_rank.has(ceili(float(total) * pct[0])):
			# If this happens, we can do extra requests. But are we really that popular?
			push_warning("%.2f percentile not in top entries" % pct[0])
	data_all.sort()
	data_friends.sort()
	return [data_all, data_friends]


func display_leaderboard(today: Array[LeaderboardData], yesterday_data: Array[LeaderboardData], level: Level) -> void:
	if not SteamManager.enabled:
		return
	var display: LeaderboardDisplay
	if not level.has_node("LeaderboardDisplay"):
		display = preload("res://game/daily_menu/LeaderboardDisplay.tscn").instantiate()
		display.modulate.a = 0
		display.visible = not Global.is_dev_mode()
		level.add_child(display)
		level.create_tween().tween_property(display, "modulate:a", 1, 1)
	display = level.get_node("LeaderboardDisplay")
	display.display(today, date, yesterday_data, yesterday)
	display.show_today_all()


func _on_dark_mode_changed(is_dark : bool):
	%Button.theme = Global.get_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
