class_name PreprocessedDifficulty

static var _current: Array[PreprocessedDifficulty]

static func _static_init() -> void:
	for _d in RandomHub.Difficulty:
		_current.append(null)

static func current(dif: RandomHub.Difficulty) -> PreprocessedDifficulty:
	if _current[dif] == null:
		_current[dif] = FileManager.load_preprocessed_difficulty(dif)
	return _current[dif]

var _success_states: Array[int]
var difficulty: RandomHub.Difficulty

func _init(dif: RandomHub.Difficulty) -> void:
	difficulty = dif

static func load_data(dif: RandomHub.Difficulty, data_: Variant) -> PreprocessedDifficulty:
	var preprocessed := PreprocessedDifficulty.new(dif)
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
