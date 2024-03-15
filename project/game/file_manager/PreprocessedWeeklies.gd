class_name PreprocessedWeeklies

# Array[Array[int]]
var _success_states: Array[Array]

static func load_data(data_: Variant) -> PreprocessedWeeklies:
	var preprocessed := PreprocessedWeeklies.new()
	if data_ == null:
		return preprocessed
	preprocessed._success_states.resize(data_.size())
	for i in data_.size():
		preprocessed._success_states[i].assign(data_[i].map(func(x): return int(x)))
	return preprocessed

func get_data() -> Variant:
	return _success_states.map(func(arr): return arr.map(func(x): return String.num_int64(x)))

static func first_monday_of_the_year(year: int) -> String:
	assert(year == 2024)
	# TODO: make it work with other years
	return "2024-01-01"

func _idx(monday: String) -> int:
	var first_monday := PreprocessedWeeklies.first_monday_of_the_year(int(monday.substr(0, 4)))
	var unix_dif := Time.get_unix_time_from_datetime_string(monday) - Time.get_unix_time_from_datetime_string(first_monday)
	var idx :=  unix_dif / (7 * 24 * 60 * 60)
	while _success_states.size() <= idx:
		var empty: Array[int] = []
		for _i in 10:
			empty.append(0)
		_success_states.append(empty)
	return idx

func success_state(monday: String, i: int) -> int:
	return _success_states[_idx(monday)][i]

func set_success_state(monday: String, i: int, state: int) -> void:
	_success_states[_idx(monday)][i] = state
