class_name DailyButton
extends RecurringMarathon

const DAY_STR := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
const WEEKDAY_EMOJI := ["🐟", "💧", "⛵", "〽️", "❓", "💦", "1️⃣"]
const LERP_F = 4.0

var today: String
var yesterday: String
var gen := RandomLevelGenerator.new()

static func _today(dt: int=0) -> String:
	var today_str := Time.get_datetime_string_from_unix_time(RecurringMarathon._unixtime_ok_timezone() - dt)
	return today_str.substr(0, today_str.find('T'))

static func _yesterday() -> String:
	return _today(24 * 60 * 60)

func _init() -> void:
	tr_name = "DAILY"
	marathon_size = 1
	streak_max_mistakes = 2

func _ready() -> void:
	super()
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	if has_node("HBox"):
		custom_minimum_size = $HBox.size

func _process(dt: float) -> void:
	if size != MainButton.size:
		size = MainButton.size
	var factor = clamp(LERP_F*dt, 0.0, 1.0)
	if has_node("HBox"):
		custom_minimum_size = lerp(custom_minimum_size, $HBox.size, factor) 
	

func _update() -> void:
	today = DailyButton._today()
	yesterday = DailyButton._yesterday()
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
		%DailyUnlockText.visible = not unlocked
		# Looks better
		%DailyHBox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if unlocked else Control.SIZE_SHRINK_CENTER
		%DailyHBox/Offset.visible = unlocked

	if not unlocked:
		return

func get_deadline() -> String:
	return today + "T23:59:59"


static func _level_name_tr(weekday: Time.Weekday) -> String:
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
		return LevelData.new(_level_name_tr(weekday), _level_desc(weekday), g.export_data(), "")
	return null

func bump_monthly_challenge() -> void:
	var score := UserData.current().bump_monthy_good_dailies(today)
	if SteamManager.enabled:
		var l_id := await RecurringMarathon.get_monthly_leaderboard(today.substr(0, today.length() - 3))
		await SteamManager.upload_leaderboard_score(l_id, score, false, LeaderboardDetails.new(await RecurringMarathon.get_my_flair()))
	elif GooglePlayGameServices.enabled:
		if today.begins_with("2024-03-"):
			GooglePlayGameServices.leaderboards_submit_score(GooglePlayGameServices.ids.leaderboard_march_challenge, score)
			await GooglePlayGameServices.leaderboards_score_submitted

func level_completed(info: Level.WinInfo, level: Level, marathon_i: int) -> void:
	super(info, level, marathon_i)
	if not info.first_win:
		return
	if info.mistakes < 3:
		await bump_monthly_challenge()

func _on_dark_mode_changed(is_dark: bool):
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

static func _mistakes_str(mistakes: int) -> String:
	var server := TranslationServer.get_translation_object(TranslationServer.get_locale())
	if mistakes == 0:
		return "🏆 0 %s" % server.tr("MISTAKES")
	else:
		return "❌ %d %s" % [
			mistakes,
			server.tr("MISTAKES" if mistakes > 1 else "MISTAKE")
		]


func share_text(mistakes: int, secs: int, marathon_i: int) -> String:
	assert(marathon_i == 1)
	var mistake_str: String = DailyButton._mistakes_str(mistakes)

	var weekday: int = Time.get_datetime_dict_from_unix_time(DailyButton._unixtime_ok_timezone()).weekday
	return "%s %s\n\n%s %s\n🕑 %s\n%s" % [
		tr("SHARE_TEXT"), DailyButton._today(),
		WEEKDAY_EMOJI[weekday], tr("%s_LEVEL" % DailyButton.DAY_STR[weekday]),
		Level.time_str(secs),
		mistake_str,
	]


# We override these functions to keep compatible with our previous daily level location.
# To remove these overrides, we would need some small migration code so that people don't double-solve a daily
# on the day this change is pushed.
func has_level_data(marathon_i: int) -> bool:
	assert(marathon_i == 1)
	return FileManager.has_daily_level(today)

func load_level_data(marathon_i: int) -> LevelData:
	assert(marathon_i == 1)
	return FileManager.load_daily_level(today)

func save_level_data(marathon_i:int, data: LevelData) -> void:
	assert(marathon_i == 1)
	FileManager.save_daily_level(today, data)

func generate_level(marathon_i: int) -> LevelData:
	assert(marathon_i == 1)
	return await DailyButton.gen_level(gen, today)

func steam_current_leaderboard() -> String:
	return "daily_%s" % [today]

func steam_previous_leaderboard() -> String:
	return "daily_%s" % [yesterday]

func current_period() -> String:
	return today

func previous_period() -> String:
	return yesterday

func level_basename() -> String:
	return FileManager._daily_basename(today)

func steam_stats() -> Array[String]:
	return ["daily2"]

func google_leaderboard() -> String:
	return GooglePlayGameServices.ids.leaderboard_daily_level_1h_mistake_penalty

func google_leaderboard_span() -> GooglePlayGameServices.TimeSpan:
	return GooglePlayGameServices.TimeSpan.TIME_SPAN_DAILY

func type() -> RecurringMarathon.Type:
	return RecurringMarathon.Type.Daily


func _on_streak_button_toggled(button_pressed):
	%StreakContainer.visible = button_pressed
	if button_pressed:
		streak_opened.emit()
