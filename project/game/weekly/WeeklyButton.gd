class_name WeeklyButton
extends RecurringMarathon

const LERP_F = 4.0

var l_gen := RandomLevelGenerator.new()

var curr_fst_day: String
var prev_fst_day: String
var deadline_str: String


func _init() -> void:
	tr_name = "WEEKLY"
	marathon_size = 10
	streak_max_mistakes = 5

static func _day_strip_time(unixtime: int) -> String:
	var day_with_time := Time.get_date_string_from_unix_time(unixtime)
	return day_with_time.substr(0, day_with_time.find('T'))


func _process(dt):
	if has_node("HBox"):
		var factor = clamp(LERP_F*dt, 0.0, 1.0)
		custom_minimum_size = lerp(custom_minimum_size, $HBox.size, factor)
	elif has_node("CenterContainer/VBox"):
		var factor = clamp(LERP_F*dt, 0.0, 1.0)
		custom_minimum_size = lerp(custom_minimum_size, $CenterContainer/VBox.size, factor) 


func _update() -> void:
	var now_unix_ok_tz := RecurringMarathon._unixtime_ok_timezone()
	var now_dict := Time.get_datetime_dict_from_unix_time(now_unix_ok_tz)
	var weekday_reset := Time.WEEKDAY_SUNDAY if RecurringMarathon.use_fixed_google_tz() else Time.WEEKDAY_MONDAY
	var days_back_till_fst_day: int = (now_dict.weekday - weekday_reset + 7) % 7
	curr_fst_day = WeeklyButton._day_strip_time(now_unix_ok_tz - days_back_till_fst_day * 24 * 60 * 60)
	prev_fst_day = WeeklyButton._day_strip_time(now_unix_ok_tz - (days_back_till_fst_day + 7) * 24 * 60 * 60)
	deadline_str = WeeklyButton._day_strip_time(now_unix_ok_tz + (-days_back_till_fst_day + 6) * 24 * 60 * 60)
	deadline_str += "T23:59:59"
	super()


static func possible_flavors() -> Array[RandomFlavors.Flavor]:
	var arr: Array[RandomFlavors.Flavor] = []
	for i in 7:
		arr.append(i as RandomFlavors.Flavor)
	arr.append_array([RandomFlavors.Flavor.Basic, RandomFlavors.Flavor.Diagonals, RandomFlavors.Flavor.Everything])
	return arr

static func gen_level(gen: RandomLevelGenerator, fst_day: String, marathon_i: int, m_size: int) -> LevelData:
	var seed_str := fst_day
	# Android resets on sunday, but we actually use the seed as monday for consistency with desktop and preprocessing
	if RecurringMarathon.use_fixed_google_tz():
		seed_str = _day_strip_time(Time.get_unix_time_from_datetime_string(fst_day) + 24 * 60 * 60)
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash(seed_str)
	# Here, use rng for stuff that only changes weekly
	var flavors := possible_flavors()
	Global.shuffle(flavors, rng)
	# And now, rng for this specific level
	rng.seed = RandomHub.consistent_hash("%s_%02d" % [seed_str, marathon_i])
	var preprocessed: int = FileManager.load_preprocessed_weeklies(int(seed_str.substr(0, 4))).success_state(seed_str, marathon_i - 1)
	if preprocessed != 0:
		rng.state = preprocessed
	var g := await RandomFlavors.gen(gen, rng, flavors[marathon_i - 1])
	if preprocessed != 0:
		assert(gen.success_state == preprocessed)
	if g != null:
		var server := TranslationServer.get_translation_object(TranslationServer.get_locale())
		var full_name := "%s (%d⁄%d)" % [server.tr("WEEKLY_LEVEL"), marathon_i, m_size]
		return LevelData.new(full_name, "", g.export_data(), "")
	return null

func generate_level(marathon_i: int) -> LevelData:
	return await WeeklyButton.gen_level(l_gen, curr_fst_day, marathon_i, marathon_size)

func share_text(mistakes: int, secs: int, marathon_i: int) -> String:
	var mistakes_str: String = DailyButton._mistakes_str(mistakes)
	var text: String
	if marathon_i == marathon_size:
		text = "%s %s" % [tr(&"WEEKLY_SHARE_COMPLETE"), DailyButton._today()]
	else:
		text = tr(&"WEEKLY_SHARE_PARTIAL") % [DailyButton._today(), marathon_i, marathon_size]
	return "{text}\n\n🕑 {time} ({total})\n{mistakes} ({total})".format({
		text = text,
		today = DailyButton._today(),
		time = Level.time_str(secs),
		mistakes = mistakes_str,
		total = tr(&"TOTAL" if marathon_i == marathon_size else &"SO_FAR"),
	})

# Returns the string representation of the time when this marathon ends
func get_deadline() -> String:
	return deadline_str

func steam_current_leaderboard() -> String:
	return level_basename()

func steam_previous_leaderboard() -> String:
	return "weekly_%s" % [prev_fst_day]

func current_period() -> String:
	return curr_fst_day

func previous_period() -> String:
	return prev_fst_day
	
func level_basename() -> String:
	return "weekly_%s" % [curr_fst_day]

func steam_stats() -> Array[String]:
	return ["weekly"]

func google_leaderboard_span() -> GooglePlayGameServices.TimeSpan:
	return GooglePlayGameServices.TimeSpan.TIME_SPAN_WEEKLY

func type() -> RecurringMarathon.Type:
	return RecurringMarathon.Type.Weekly


func _on_streak_button_toggled(button_pressed):
	%StreakContainer.visible = button_pressed
	if button_pressed:
		streak_opened.emit()
