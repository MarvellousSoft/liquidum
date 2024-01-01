class_name PreprocessedDifficulty

var _success_states: Array[int]
var difficulty: RandomHub.Difficulty

func _init(dif: RandomHub.Difficulty) -> void:
	difficulty = dif

static func load_data(dif: RandomHub.Difficulty, data_: Variant) -> PreprocessedDifficulty:
	var preprocessed := PreprocessedDifficulty.new(dif)
	if data_ == null:
		return preprocessed
	preprocessed._success_states.assign(data_)
	return preprocessed

func get_data() -> Variant:
	return _success_states

func _idx(date_dict: Dictionary) -> int:
	# Yes, I'm assuming all months are 31-day long and leaving some holes. Sue me.
	return (date_dict.month - 1) * 31 + date_dict.day - 1

func success_state(idx: int) -> int:
	return _success_states[idx] if idx < _success_states.size() else 0

func set_success_state(idx: int, state: int) -> void:
	while idx >= _success_states.size():
		_success_states.append(0)
	_success_states[idx] = state
