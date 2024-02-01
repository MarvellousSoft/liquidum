class_name PreprocessedDailies

var _success_states: Array[int]

func _init() -> void:
	_success_states.resize(31 * 12)

static func load_data(data_: Variant) -> PreprocessedDailies:
	var preprocessed := PreprocessedDailies.new()
	if data_ == null:
		return preprocessed
	preprocessed._success_states.assign(data_.map(func(x): return int(x)))
	return preprocessed

func get_data() -> Variant:
	return _success_states.map(func(x): return String.num_int64(x))

func _idx(date_dict: Dictionary) -> int:
	# Yes, I'm assuming all months are 31-day long and leaving some holes. Sue me.
	return (date_dict.month - 1) * 31 + date_dict.day - 1

func success_state(date_dict: Dictionary) -> int:
	return _success_states[_idx(date_dict)]

func set_success_state(date_dict: Dictionary, state: int) -> void:
	_success_states[_idx(date_dict)] = state
