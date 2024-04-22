class_name RecurringMarathon
extends Control

# 27 hours, enough
const MAX_TIME := 100000
const DEV_IDS := {76561198046896163: true, 76561198046336325: true}

signal streak_opened

enum Type { Daily = 0, Weekly = 1 }

# Initialise these on the constructor
var tr_name: String
var marathon_size: int
var streak_max_mistakes: int
var copied_tween: Tween = null



@onready var MainButton: Button = %MainButton
@onready var TimeLeft: Label = %TimeLeft
@onready var OngoingSolution = %OngoingSolution
@onready var Share = %Share
@onready var Completed = %Completed
@onready var NotCompleted = %NotCompleted
@onready var CurStreak = %CurStreak
@onready var BestStreak = %BestStreak

var deadline: int = -1
var already_uploaded := false

static func type_name(t: Type) -> String:
	return Type.find_key(t).to_lower()

# UTC unix time
static func _unixtime() -> int:
	if SteamManager.enabled:
		return SteamManager.steam.getServerRealTime()
	return int(Time.get_unix_time_from_system())

static func use_fixed_google_tz() -> bool:
	return OS.get_name() == "Android"

static func _timezone_bias_secs() -> int:
	if use_fixed_google_tz():
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
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	if has_node("HBox"):
		custom_minimum_size = $HBox.size

func _enter_tree() -> void:
	Global.dev_mode_toggled.connect(_on_something_changed)
	Profile.unlock_everything_changed.connect(_on_something_changed)
	call_deferred(&"_update")

func _exit_tree() -> void:
	Global.dev_mode_toggled.disconnect(_on_something_changed)
	Profile.unlock_everything_changed.disconnect(_on_something_changed)

func _on_something_changed(_on: bool) -> void:
	_update()

func _get_marathon_completed() -> int:
	var last_level := 0
	while last_level + 1 <= marathon_size and has_level_data(last_level + 1):
		last_level += 1
	if last_level == 0:
		return 0
	var save := load_level_save(last_level)
	return last_level - 1 + int(save != null and save.is_completed())

func _next_level_to_play() -> int:
	if marathon_size == 1:
		return 1
	var completed := _get_marathon_completed()
	if completed == marathon_size:
		var replay_completed: int = UserData.current().replay_completed[type()]
		return (replay_completed % marathon_size) + 1
	else:
		return completed + 1

func _update() -> void:
	var unlocked := RecurringMarathon.is_unlocked()
	MainButton.disabled = not unlocked
	TimeLeft.visible = unlocked
	deadline = int(Time.get_unix_time_from_datetime_string(get_deadline())) - RecurringMarathon._timezone_bias_secs()
	var marathon_completed := _get_marathon_completed()
	var save := load_level_save(marathon_completed + 1) if marathon_completed < marathon_size else null
	OngoingSolution.visible = save != null and not save.is_solution_empty()
	Completed.visible = marathon_completed == marathon_size
	Share.visible = Completed.visible
	NotCompleted.visible = not Completed.visible and unlocked
	if has_node("%TimeBox"):
		%TimeBox.visible = unlocked
	if Global.is_mobile:
		%LeaderboardsButton.visible = unlocked
		%LeaderboardsButton.modulate.a = 1.0 if GoogleIntegration.available() or AppleIntegration.available() else 0.0
		# Looks better
		%DailyHBox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if unlocked else Control.SIZE_SHRINK_CENTER
		%DailyHBox/OffsetRight.visible = unlocked and Completed.visible
	MainButton.text = tr("%s_BUTTON" % tr_name)
	if unlocked:
		MainButton.tooltip_text = "%s_TOOLTIP" % [tr_name]
		if marathon_size > 1:
			MainButton.text = "%s (%d⁄%d)" % [tr("%s_BUTTON" % tr_name), mini(marathon_completed + 1, marathon_size), marathon_size]
	else:
		MainButton.tooltip_text = "RECURRING_TOOLTIP_DISABLED"
		return
	_update_time_left()
	_update_streak()

func _update_time_left() -> void:
	if MainButton.disabled:
		return
	var secs_left := deadline - RecurringMarathon._unixtime()
	if secs_left > 0:
		var num: int
		var txt: String
		var repl := {}
		if secs_left >= 24 * 60 * 60:
			num = secs_left / (24 * 60 * 60)
			txt = "DAYS_LEFT"
			var hours := (secs_left % (24 * 60 * 60)) / (60 * 60)
			repl["m"] = hours
		elif secs_left >= 60 * 60:
			num = secs_left / (60 * 60)
			txt = "HOURS_LEFT"
		else:
			num = secs_left / 60
			txt = "MINUTES_LEFT"
		repl["s"] = "s" if num != 1 else ""
		repl["n"] = num
		TimeLeft.text = tr(txt).format(repl)
	else:
		_update()

func _update_streak() -> void:
	var data := UserData.current()
	var id := type()
	if data.current_streak[id] > 0 and not data.last_day[id] in [current_period(), previous_period()]:
		data.current_streak[id] = 0
		UserData.save()
	if has_node("%StreakButton"):
		%StreakButton.text = str(data.current_streak[type()])
	CurStreak.text = str(data.current_streak[type()])
	BestStreak.text = str(data.best_streak[type()])

func _on_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")

func _on_main_button_pressed() -> void:
	await gen_and_play(true)

func gen_and_play(push_scene: bool) -> void:
	# Update date if needed
	_update_time_left()
	MainButton.disabled = true
	var is_replay: bool = _get_marathon_completed() == marathon_size
	if not is_replay:
		UserData.current().replay_completed[type()] = 0
	var marathon_i := _next_level_to_play()
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
		level.reset_text = &"CONFIRM_RESET_RECURRING"
		level.won.connect(level_completed.bind(level, marathon_i, is_replay))
		level.share.connect(share.bind(marathon_i))
		level.reset_mistakes_on_empty = false
		level.reset_mistakes_on_reset = false
		level.recurring_marathon_left = marathon_size - marathon_i
		if marathon_i > 1:
			var prev_save := load_level_save(marathon_i - 1)
			if prev_save != null and prev_save.is_completed():
				level.initial_mistakes = prev_save.mistakes
				level.running_time = prev_save.timer_secs
		elif is_replay:
			# Manually reset the save, since we have reset_mistakes_on_empty
			var save := load_level_save(1)
			assert(save.is_completed())
			if save.is_completed() and save.is_solution_empty():
				save.mistakes = 0
				save.timer_secs = 0.0
				FileManager.save_level(_level_name(1), save)
		TransitionManager.change_scene(level, push_scene)
		await level.ready
		if SteamManager.enabled:
			await load_and_display_leaderboard(level)

	MainButton.disabled = false

func load_and_display_leaderboard(level: Level) -> void:
	var display: LeaderboardDisplay = null
	if Global.is_mobile:
		display = LeaderboardDisplay.get_or_create(level, tr_name, true)
	var l_data := await RecurringMarathon.get_leaderboard_data(steam_current_leaderboard())
	if l_data.size() > 0 and l_data[0].has_self:
		already_uploaded = true
	var y_data := await RecurringMarathon.get_leaderboard_data(steam_previous_leaderboard())
	display_leaderboard(display, l_data, y_data, level)
	

func close_streak():
	%StreakButton.button_pressed = false

static func get_monthly_leaderboard(month_str: String) -> int:
	return await SteamManager.get_or_create_leaderboard("monthly_%s" % [month_str], \
			SteamManager.steam.LEADERBOARD_SORT_METHOD_DESCENDING, SteamManager.steam.LEADERBOARD_DISPLAY_TYPE_NUMERIC)

static func get_my_flair() -> SteamFlair:
	var flair := FlairManager.get_current_flair()
	if flair == null:
		return null
	else:
		return flair.to_steam_flair()

static func upload_leaderboard(l_id: String, info: Level.WinInfo, keep_best: bool) -> void:
	# Steam needs to create the leaderboards dinamically
	await SteamManager.ld_mutex.lock()
	await StoreIntegrations.leaderboard_create_if_not_exists(l_id, StoreIntegrations.SortMethod.SmallestFirst)
	var details: LeaderboardDetails = null
	if SteamIntegration.available():
		details = LeaderboardDetails.new(get_my_flair())
	await StoreIntegrations.leaderboard_upload_completion(l_id, info.time_secs, info.total_marathon_mistakes, keep_best, LeaderboardDetails.to_arr(details))
	SteamManager.ld_mutex.unlock()

class ListEntry:
	var global_rank: int
	var text: String
	# Might be null
	var image: Image
	var mistakes: int
	var secs: int
	var flair: SteamFlair

	static func create(raw: StoreIntegrations.LeaderboardEntry) -> ListEntry:
		var entry := ListEntry.new()
		entry.global_rank = raw.rank
		entry.mistakes = raw.mistakes
		entry.secs = raw.secs
		entry.flair = raw.extra_data.get("flair", null)
		entry.text = raw.display_name
		if SteamManager.enabled and raw.extra_data.has("steam_id"):
			SteamManager.steam.getPlayerAvatar(SteamManager.steam.AVATAR_LARGE, raw.extra_data.steam_id)
			var ret: Array = await SteamManager.steam.avatar_loaded
			entry.image = Image.create_from_data(ret[1], ret[1], false, Image.FORMAT_RGBA8, ret[2])
			entry.image.generate_mipmaps()
		return entry

class LeaderboardData:
	# Is this user present on list?
	var has_self: bool = false
	# List of friends and percentiles
	var list: Array[ListEntry]
	func is_empty() -> bool:
		return list.is_empty()
	func sort() -> void:
		list.sort_custom(func(entry_a: ListEntry, entry_b: ListEntry) -> bool: return entry_a.global_rank < entry_b.global_rank)

static func get_leaderboard_data(l_id: String) -> Array[LeaderboardData]:
	var raw := await StoreIntegrations.leaderboard_download_completion(l_id, 1, 100)
	if raw.entries.is_empty():
		return []
	var data := LeaderboardData.new()
	data.has_self = raw.has_self
	for raw_entry in raw.entries:
		data.list.append(await ListEntry.create(raw_entry))
	return [data]

func display_leaderboard(display: LeaderboardDisplay, current_data: Array[LeaderboardData], previous_data: Array[LeaderboardData], level: Level) -> void:
	if current_data.is_empty() and previous_data.is_empty():
		return
	if display == null:
		display = LeaderboardDisplay.get_or_create(level, tr_name, true)
	if not display.is_node_ready():
		await display.ready
	display.display(current_data, current_period(), previous_data, previous_period())
	display.show_current_all()

func level_completed(info: Level.WinInfo, level: Level, marathon_i: int, is_replay: bool) -> void:
	var data := UserData.current()
	var id := type()
	if is_replay:
		data.replay_completed[id] = marathon_i
	level.get_node("%ShareButton").visible = true
	var stats := StatsTracker.instance()
	if info.first_win and marathon_i == 1 and marathon_size > 1:
		stats.increment_recurring_started(id)
	if not info.first_win or marathon_i < marathon_size:
		return
	stats.increment_recurring_all(id)
	if info.total_marathon_mistakes <= streak_max_mistakes:
		stats.increment_recurring_good(id)
		if info.total_marathon_mistakes == 0:
			await stats.unlock_recurring_no_mistakes(id)
		# It the streak was broken this would be handled in _update_streak
		if current_period() != data.last_day[id]:
			data.last_day[id] = current_period()
			data.current_streak[id] += 1
			data.best_streak[id] = maxi(data.best_streak[id], data.current_streak[id])
			UserData.save()
	else:
		if data.current_streak[id] > 0:
			data.current_streak[id] = 0
			UserData.save()
	if not already_uploaded:
		await RecurringMarathon.upload_leaderboard(current_leaderboard(), info, false)
		if SteamManager.enabled:
			var l_data := await RecurringMarathon.get_leaderboard_data(steam_current_leaderboard())
			display_leaderboard(null, l_data, [], level)
	if not MobileRequestReview.just_requested_review:
		StoreIntegrations.leaderboard_show(current_leaderboard(), google_leaderboard_span())

func _on_dark_mode_changed(is_dark: bool):
	MainButton.theme = Global.get_theme(is_dark)

func _on_share_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	var save := load_level_save(marathon_size)
	if save != null and save.is_completed():
		share(save.best_mistakes, int(save.best_time_secs), marathon_size)
		if not Global.is_mobile:
			# Mobile already has enough feedback because it opens a dialog
			if copied_tween != null:
				copied_tween.kill()
			var label: Label = %CopiedLabel
			label.show()
			label.modulate.a = 1.0
			copied_tween = create_tween()
			copied_tween.tween_property(label, "modulate:a", 0.0, 1.0)
			copied_tween.tween_callback(label.hide)

static func do_share(text: String) -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("GodotAndroidShare"):
		var android_share = Engine.get_singleton("GodotAndroidShare")
		android_share.shareText("Liquidum", "subject", text)
	else:
		DisplayServer.clipboard_set(text)

func _on_leaderboards_button_pressed() -> void:
	assert(Global.is_mobile)
	if OS.is_debug_build():
		%LeaderboardsButton.disabled = true
		await load_and_display_leaderboard(null)
		%LeaderboardsButton.disabled = false
	else:
		await StoreIntegrations.leaderboard_show(RecurringMarathon.type_name(type()), google_leaderboard_span())

func share(mistakes: int, secs: int, marathon_i: int) -> void:
	RecurringMarathon.do_share(share_text(mistakes, secs, marathon_i))

func _level_name(marathon_i: int) -> String:
	return "%s_%d" % [level_basename(), marathon_i]

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

func google_leaderboard_span() -> GooglePlayGameServices.TimeSpan:
	return GridModel.must_be_implemented()

func share_text(_mistakes: int, _secs: int, _marathon_i: int) -> String:
	return GridModel.must_be_implemented()

func type() -> Type:
	return GridModel.must_be_implemented()

func current_leaderboard() -> String:
	if SteamIntegration.available():
		# Steam uses a different leaderboard each day
		return steam_current_leaderboard()
	else:
		return RecurringMarathon.type_name(type())
