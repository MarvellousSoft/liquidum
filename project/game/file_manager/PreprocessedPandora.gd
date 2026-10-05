class_name PreprocessedPandora

static var _current: Array[PreprocessedPandora] = []

@warning_ignore("shadowed_variable")
static func current(mode: int) -> PreprocessedPandora:
	while _current.size() <= mode:
		_current.append(null)
	if _current[mode] == null:
		_current[mode] = FileManager.load_preprocessed_pandora(mode)
	return _current[mode]

var _success_states: Array[int] = []
var mode: int

func _init(mode_: int) -> void:
	mode = mode_

static func load_data(mode_: int, data_: Variant) -> PreprocessedPandora:
	var preprocessed := PreprocessedPandora.new(mode_)
	if data_ == null:
		return preprocessed
	preprocessed._success_states.assign(data_.map(func(x): return int(x)))
	return preprocessed

func get_data() -> Variant:
	return _success_states.map(func(x): return String.num_int64(x))

func success_state(idx: int) -> int:
	return _success_states[idx] if idx >= 0 and idx < _success_states.size() else 0

func set_success_state(idx: int, state: int) -> void:
	while idx >= _success_states.size():
		_success_states.append(0)
	_success_states[idx] = state
