class_name RecurringMarathon
extends Control

# 27 hours, enough
const MAX_TIME := 100000
const DEV_IDS := {76561198046896163: true, 76561198046336325: true}

@export var tr_name: String
@export var marathon_size: int

@onready var MainButton: Button = %MainButton
@onready var TimeLeft: Label = %TimeLeft

var deadline: int = -1
var already_uploaded := false

# UTC unix time
static func _unixtime() -> int:
	if SteamManager.enabled:
		return SteamManager.steam.getServerRealTime()
	return int(Time.get_unix_time_from_system())

static func _timezone_bias_secs() -> int:
	if OS.get_name() == "Android":
		# UTC-7 because that's when google play leaderboards reset
		# https://developers.google.com/games/services/common/concepts/leaderboards
		return - 7 * 60 * 60
	else:
		return int(Time.get_time_zone_from_system().bias) * 60

static func _unixtime_ok_timezone() -> int:
	return _unixtime() + _timezone_bias_secs()

static func is_unlocked() -> bool:
	return Global.is_dev_mode() or Profile.get_option("unlock_everything") or CampaignLevelLister.section_complete(4)

func _ready() -> void:
	Global.dev_mode_toggled.connect(func(_on): _update())
	Profile.unlock_everything_changed.connect(func(_on): _update())

func _enter_tree() -> void:
	call_deferred(&"_update")

func _get_marathon_progress() -> int:
	var last_level := 0
	while last_level + 1 < marathon_size and has_level_data(last_level):
		last_level += 1
	if not has_level_save(last_level):
		return last_level
	var save := load_level_save(last_level)
	return last_level + int(save != null and save.is_completed())

func _update() -> void:
	var unlocked := RecurringMarathon.is_unlocked()
	MainButton.disabled = not unlocked
	TimeLeft.visible = unlocked
	deadline = int(Time.get_unix_time_from_datetime_string(get_deadline())) - RecurringMarathon._timezone_bias_secs()
	if unlocked:
		MainButton.tooltip_text = "%s_TOOLTIP" % [tr_name]
		if marathon_size > 1:
			MainButton.text = "%s (%d⁄%d)" % [tr("%s_BUTTON" % tr_name), _get_marathon_progress(), marathon_size]
	else:
		MainButton.tooltip_text = "RECURRING_TOOLTIP_DISABLED"
		return
	_update_time_left()

func _update_time_left() -> void:
	if MainButton.disabled:
		return
	var secs_left := deadline - RecurringMarathon._unixtime()
	if secs_left > 0:
		var num: int
		var txt: String
		if secs_left >= 24 * 60 * 60:
			num = secs_left / (24 * 60 * 60)
			txt = "DAYS_LEFT"
		elif secs_left >= 60 * 60:
			num = secs_left / (60 * 60)
			txt = "HOURS_LEFT"
		else:
			num = secs_left / 60
			txt = "MINUTES_LEFT"
		txt = tr(txt).format({"s": "s" if num > 1 else ""})
		TimeLeft.text = "%s %s" % [TextServerManager.get_primary_interface().format_number(str(num)), txt]
	else:
		_update()

func _on_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")

func _on_main_button_pressed() -> void:
	# Update date if needed
	_update_time_left()
	MainButton.disabled = true
	var marathon_i := _get_marathon_progress() % marathon_size
	if not has_level_data(marathon_i):
		GeneratingLevel.enable()
		var level := await generate_level(marathon_i)
		GeneratingLevel.disable()
		if level != null:
			# TODO: put some marathon information in the level
			save_level_data(marathon_i, level)
		else:
			return
	var level_data := load_level_data(marathon_i)
	already_uploaded = false
	if level_data != null:
		var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), _level_name(marathon_i), level_data.full_name, level_data.description, steam_stats())
		level.reset_text = &"CONFIRM_RESET_DAILY"
		level.won.connect(level_completed.bind(level, marathon_i))
		level.reset_mistakes_on_empty = false
		level.reset_mistakes_on_reset = false
		TransitionManager.push_scene(level)
		await level.ready
		if SteamManager.enabled:
			var l_id := await load_current_leaderboard()
			var l_data := await get_leaderboard_data(l_id)
			if l_data[0].has_self:
				already_uploaded = true
			l_id = await load_previous_leaderboard()
			var y_data := await get_leaderboard_data(l_id)
			display_leaderboard(l_data, y_data, level)

	MainButton.disabled = false

func _load_leaderboard(ld_name: String) -> int:
	if ld_name.is_empty():
		return 0
	else:
		return await SteamManager.get_or_create_leaderboard(ld_name, SteamManager.steam.LEADERBOARD_SORT_METHOD_ASCENDING, SteamManager.steam.LEADERBOARD_DISPLAY_TYPE_TIME_SECONDS)

func load_current_leaderboard() -> int:
	return await _load_leaderboard(steam_current_leaderboard())

func load_previous_leaderboard() -> int:
	return await _load_leaderboard(steam_previous_leaderboard())

func get_monthly_leaderboard(month_str: String) -> int:
	return await SteamManager.get_or_create_leaderboard("monthly_%s" % [month_str], \
			SteamManager.steam.LEADERBOARD_SORT_METHOD_DESCENDING, SteamManager.steam.LEADERBOARD_DISPLAY_TYPE_NUMERIC)

func get_my_flair() -> Flair:
	if DEV_IDS.has(SteamManager.steam.getSteamID()):
		return Flair.new("dev", Color(0.0784314, 0.364706, 0.529412, 1), Color(0.270588, 0.803922, 0.698039, 1))
	var last_month_dict := Time.get_datetime_dict_from_datetime_string(DailyButton._today(), false)
	if last_month_dict.month == 1:
		last_month_dict.month = 12
		last_month_dict.year -= 1
	else:
		last_month_dict.month -= 1

	var l_id := await get_monthly_leaderboard("%04d-%02d" % [last_month_dict.year, last_month_dict.month])
	SteamManager.steam.downloadLeaderboardEntriesForUsers([SteamManager.steam.getSteamID()], l_id)
	var ret: Array = await SteamManager.steam.leaderboard_scores_downloaded
	if not ret[2].is_empty() and ret[2][0].score >= 15:
		return Flair.new("pro", Color(0.0784314, 0.364706, 0.529412, 1), Color(0.270588, 0.803922, 0.698039, 1))
	return null

func upload_leaderboard(l_id: int, info: Level.WinInfo) -> void:
	if not SteamManager.enabled:
		return
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	var score: int = mini(info.mistakes, 1000) * MAX_TIME + mini(floori(info.time_secs), MAX_TIME - 1)
	var flair := await get_my_flair()
	SteamManager.steam.uploadLeaderboardScore(score, false, LeaderboardDetails.new(flair).to_arr(), l_id)
	var ret: Array = await SteamManager.steam.leaderboard_score_uploaded
	if not ret[0]:
		push_warning("Failed to upload entry for %s" % [tr_name])

class ListEntry:
	var global_rank: int
	# Name. Might be "10% percentile"
	var text: String
	# Might be null
	var image: Image
	var mistakes: int
	var secs: int

	var flair: Flair
	static func create(data: Dictionary, override_name:="") -> ListEntry:
		var entry := ListEntry.new()
		entry.global_rank = data.global_rank
		entry.mistakes = data.score / MAX_TIME
		entry.secs = data.score % MAX_TIME
		var details := LeaderboardDetails.from_arr(data.get("details", PackedInt32Array()))
		entry.flair = details.flair
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
	SteamManager.steam.setLeaderboardDetailsMax(64)
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
	SteamManager.steam.setLeaderboardDetailsMax(0)
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

func display_leaderboard(current_data: Array[LeaderboardData], previous_data: Array[LeaderboardData], level: Level) -> void:
	if not SteamManager.enabled:
		return
	var display: LeaderboardDisplay
	if not level.has_node("LeaderboardDisplay"):
		display = preload ("res://game/daily_menu/LeaderboardDisplay.tscn").instantiate()
		display.tr_name = tr_name
		display.modulate.a = 0
		display.visible = not Global.is_dev_mode()
		level.add_child(display)
		level.create_tween().tween_property(display, "modulate:a", 1, 1)
	display = level.get_node("LeaderboardDisplay")
	display.display(current_data, current_period(), previous_data, previous_period())
	display.show_current_all()

func level_completed(info: Level.WinInfo, level: Level, marathon_i: int) -> void:
	# TODO: handle marathon
	level.get_node("%ShareButton").visible = true
	if not info.first_win:
		return
	if SteamManager.enabled:
		var l_id := await load_current_leaderboard()
		if l_id != 0:
			if not already_uploaded and marathon_i == marathon_size - 1:
				await upload_leaderboard(l_id, info)
			var l_data := await get_leaderboard_data(l_id)
			display_leaderboard(l_data, [], level)
	elif GooglePlayGameServices.enabled:
		if not already_uploaded:
			var score: int = int(info.time_secs * 1000) + 60 * 60 * info.mistakes
			GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_daily_level_1h_mistake_penalty, float(score))
			await GooglePlayGameServices.leaderboards_score_submitted
		GooglePlayGameServices.leaderboards_show_for_time_span_and_collection(GooglePlayGameServices.ids.leaderboard_daily_level_1h_mistake_penalty, \
		   GooglePlayGameServices.TimeSpan.TIME_SPAN_DAILY, GooglePlayGameServices.Collection.COLLECTION_PUBLIC)

func _level_name(marathon_i: int) -> String:
	var base_name := level_basename()
	if marathon_size > 1:
		base_name += "_%d" % [marathon_i]
	return base_name

func has_level_save(marathon_i: int) -> bool:
	return FileManager.has_level(_level_name(marathon_i))

func load_level_save(marathon_i: int) -> UserLevelSaveData:
	return FileManager.load_level(_level_name(marathon_i))

func has_level_data(marathon_i: int) -> bool:
	return FileManager.has_recurring_level_data(_level_name(marathon_i))

func load_level_data(marathon_i: int) -> LevelData:
	return FileManager.load_recurring_level_data(_level_name(marathon_i))

func save_level_data(marathon_i: int, data: LevelData) -> void:
	return FileManager.save_recurring_level_data(_level_name(marathon_i), data)

func generate_level(_marathon_i: int) -> LevelData:
	return await GridModel.must_be_implemented()

# Returns the string representation of the time when this marathon ends
func get_deadline() -> String:
	return GridModel.must_be_implemented()

func steam_current_leaderboard() -> String:
	return GridModel.must_be_implemented()

func steam_previous_leaderboard() -> String:
	return GridModel.must_be_implemented()

func current_period() -> String:
	return GridModel.must_be_implemented()

func previous_period() -> String:
	return GridModel.must_be_implemented()
	
func level_basename() -> String:
	return GridModel.must_be_implemented()

func steam_stats() -> Array[String]:
	return GridModel.must_be_implemented()
