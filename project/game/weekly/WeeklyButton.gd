class_name WeeklyButton
extends RecurringMarathon

const FLAVORS: Array[RandomFlavors.Flavor] = [
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
	RandomFlavors.Flavor.Basic,
]

var l_gen := RandomLevelGenerator.new()

var curr_monday: String
var prev_monday: String
var deadline_str: String

func _init() -> void:
	tr_name = "WEEKLY"
	marathon_size = 10

func _day_strip_time(unixtime: int) -> String:
	var day_with_time := Time.get_date_string_from_unix_time(unixtime)
	return day_with_time.substr(0, day_with_time.find('T'))

func _update() -> void:
	var now_unix_ok_tz := RecurringMarathon._unixtime_ok_timezone()
	var now_dict := Time.get_datetime_dict_from_unix_time(now_unix_ok_tz)
	var days_back_till_monday: int = (now_dict.weekday - Time.WEEKDAY_MONDAY + 7) % 7
	curr_monday = _day_strip_time(now_unix_ok_tz - days_back_till_monday * 24 * 60 * 60)
	prev_monday = _day_strip_time(now_unix_ok_tz - (days_back_till_monday + 7) * 24 * 60 * 60)
	deadline_str = _day_strip_time(now_unix_ok_tz + (-days_back_till_monday + 6) * 24 * 60 * 60)
	deadline_str += "T23:59:59"
	super()

func generate_level(marathon_i: int) -> LevelData:
	var rng := RandomNumberGenerator.new()
	var g := await RandomFlavors.gen(l_gen, rng, FLAVORS[marathon_i])
	if g != null:
		return LevelData.new("BLAAAA", "BLADESC", g.export_data(), "")
	return null

# Returns the string representation of the time when this marathon ends
func get_deadline() -> String:
	return deadline_str

func steam_current_leaderboard() -> String:
	return level_basename()

func steam_previous_leaderboard() -> String:
	return "weekly_%s" % [prev_monday]

func current_period() -> String:
	return curr_monday

func previous_period() -> String:
	return prev_monday
	
func level_basename() -> String:
	return "weekly_%s" % [curr_monday]

func steam_stats() -> Array[String]:
	return ["weekly"]
