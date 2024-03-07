class_name PreprocessedEndless

static var _current: Array[PreprocessedEndless]

static func current(section: int) -> PreprocessedEndless:
	while _current.size() < section:
		_current.append(null)
	if _current[section - 1] == null:
		_current[section - 1] = FileManager.load_preprocessed_endless(section)
	return _current[section - 1]

var _success_states: Array[int]

static func load_data(data_: Variant) -> PreprocessedEndless:
	var preprocessed := PreprocessedEndless.new()
	if data_ == null:
		return preprocessed
	preprocessed._success_states.assign(data_.map(func(x): return int(x)))
	return preprocessed

func get_data() -> Variant:
	return _success_states.map(func(x): return String.num_int64(x))

func success_state(idx: int) -> int:
	return _success_states[idx] if idx < _success_states.size() else 0

func set_success_state(idx: int, state: int) -> void:
	while idx >= _success_states.size():
		_success_states.append(0)
	_success_states[idx] = state
