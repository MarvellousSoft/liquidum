class_name DailyButton
extends RecurringMarathon

const DAY_STR := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
const WEEKDAY_EMOJI := ["🐟", "💧", "⛵", "〽️", "❓", "💦", "1️⃣"]


@onready var OngoingSolution = %OngoingSolution
@onready var Completed = %Completed
@onready var NotCompleted = %NotCompleted
@onready var CurStreak = %CurStreak
@onready var BestStreak = %BestStreak

var date: String
var gen := RandomLevelGenerator.new()

func _init() -> void:
	tr_name = "DAILY"

func _ready() -> void:
	super()
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))

func _process(_dt: float) -> void:
	if size != MainButton.size:
		size = MainButton.size

func _update() -> void:
	super()
	var unlocked := RecurringMarathon.is_unlocked()
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
	if Global.is_mobile:
		%LeaderboardsButton.visible = unlocked
		%LeaderboardsButton.modulate.a = 1.0 if GooglePlayGameServices.enabled else 0.0
	%StreakContainer.visible = unlocked
	NotCompleted.visible = unlocked
	Completed.visible = false
	OngoingSolution.visible = false
	if Global.is_mobile:
		%DailyUnlockText.visible = not unlocked
		# Looks better
		%DailyHBox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if unlocked else Control.SIZE_SHRINK_CENTER

	date = DailyButton._today()
	yesterday = DailyButton._yesterday()

	if not unlocked:
		OngoingSolution.hide()
		return
	
	if has_level_save():
		var save := load_level_save()
		if save:
			OngoingSolution.visible = not save.is_solution_empty()
			Completed.visible = save.is_completed()
			NotCompleted.visible = not save.is_completed()
	_update_streak()

func get_deadline() -> String:
	return today + "T23:59:59"


func _update_streak() -> void:
	var data := UserData.current()
	if data.current_streak > 0 and data.last_day < yesterday:
		data.current_streak = 0
		UserData.save()
	CurStreak.text = str(data.current_streak)
	BestStreak.text = str(data.best_streak)

static func _level_name(weekday: Time.Weekday) -> String:
	return "%s_LEVEL" % DAY_STR[weekday]


static func _level_desc(weekday: Time.Weekday) -> String:
	return "%s_LEVEL_DESC" % DAY_STR[weekday]


static func gen_level(l_gen: RandomLevelGenerator, today_str: String) -> LevelData:
	var date_dict := Time.get_datetime_dict_from_datetime_string(today_str, true)
	var weekday: Time.Weekday = date_dict.weekday
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash(today_str)
	var preprocessed_state := FileManager.load_dailies(date_dict.year).success_state(date_dict)
	if preprocessed_state != 0:
		rng.state = preprocessed_state
	var g: GridModel = await RandomFlavors.gen(l_gen, rng, weekday as RandomFlavors.Flavor)
	if preprocessed_state != 0:
		assert(preprocessed_state == l_gen.success_state)
	if g != null:
		return LevelData.new(_level_name(weekday), _level_desc(weekday), g.export_data(), "")
	return null


func bump_monthly_challenge() -> void:
	var score := UserData.current().bump_monthy_good_dailies(today)
	if SteamManager.enabled:
		var l_id := await get_monthly_leaderboard(today.substr(0, today.length() - 3))
		SteamManager.steam.uploadLeaderboardScore(score, true, PackedInt32Array(), l_id)
		var ret: Array = await SteamManager.steam.leaderboard_score_uploaded
		if not ret[0]:
			push_warning("Failed to upload entry for monthly %s" % [today])
	elif GooglePlayGameServices.enabled:
		if today.begins_with("2024-03-"):
			GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_march_challenge, score)
			await GooglePlayGameServices.leaderboards_score_submitted


func level_completed(info: Level.WinInfo, level: Level) -> void:
	super(info, level)
	if not info.first_win:
		return
	if info.mistakes < 3:
		await bump_monthly_challenge()
	var stats := StatsTracker.instance()
	stats.increment_daily_all()
	var data := UserData.current()
	if info.mistakes < 3:
		stats.increment_daily_good()
		if info.mistakes == 0:
			stats.unlock_daily_no_mistakes()
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


func _on_dark_mode_changed(is_dark : bool):
	MainButton.theme = Global.get_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_leaderboards_button_pressed() -> void:
	assert(Global.is_mobile)
	if not GooglePlayGameServices.enabled:
		return
	GooglePlayGameServices.leaderboards_show_for_time_span_and_collection(
	  GooglePlayGameServices.ids.leaderboard_daily_level_1h_mistake_penalty,
	  GooglePlayGameServices.TimeSpan.TIME_SPAN_DAILY,
	  GooglePlayGameServices.Collection.COLLECTION_PUBLIC)

static func share(mistakes: int, secs: int) -> void:
	AudioManager.play_sfx("button_pressed")
	var server := TranslationServer.get_translation_object(TranslationServer.get_locale())
	var mistake_str: String
	if mistakes == 0:
		mistake_str = "🏆 0 %s" % server.tr("MISTAKES")
	else:
		mistake_str = "❌ %d %s" % [
			mistakes,
			server.tr("MISTAKES" if mistakes > 1 else "MISTAKE")
		]

	var weekday: int = Time.get_datetime_dict_from_unix_time(DailyButton._unixtime_ok_timezone()).weekday
	var text := "%s %s\n\n%s %s\n🕑 %s\n%s" % [
		server.tr("SHARE_TEXT"), DailyButton._today(),
		WEEKDAY_EMOJI[weekday], server.tr("%s_LEVEL" % DailyButton.DAY_STR[weekday]),
		Level.time_str(secs),
		mistake_str,
	]
	if OS.get_name() == "Android" and Engine.has_singleton("GodotAndroidShare"):
		var android_share = Engine.get_singleton("GodotAndroidShare")
		android_share.shareText("Liquidum", "subject", text)
	else:
		DisplayServer.clipboard_set(text)

var copied_tween: Tween = null

func _on_share_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	if FileManager.has_daily_level(date):
		var save := FileManager.load_level(FileManager._daily_basename(date))
		if save and save.is_completed():
			DailyButton.share(save.best_mistakes, int(save.best_time_secs))
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



func has_level_data() -> bool:
	return FileManager.has_daily_level(date)

func load_level_data() -> LevelData:
	return FileManager.load_daily_level(date)

func save_level_data(data: LevelData) -> void:
	FileManager.save_daily_level(date, data)

func has_level_save() -> bool:
	return FileManager.has_daily_level(date)

func load_level_save() -> UserLevelSaveData:
	return FileManager.load_level(FileManager._daily_basename(date))

func generate_level() -> LevelData:
	return await DailyButton.gen_level(gen, date)

func steam_current_leaderboard() -> String:
	return "daily_%s" % [date]

func steam_previous_leaderboard() -> String:
	return "daily_%s" % [yesterday]
