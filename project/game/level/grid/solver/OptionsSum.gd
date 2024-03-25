class_name OptionsSum

# Like SubsetSum, but instead you have a bunch of choices between many numbers

static var memo := {}

# options is Array[Array[float]]
static func _dp(goal: float, options: Array[Array]) -> bool:
	if goal == 0:
		return options.is_empty()
	if goal < 0 or options.is_empty():
		return false
	if memo.has([goal, options]):
		return memo[[goal, options]]
	var new: Array[Array] = options.duplicate()
	var last_option: Array = new.pop_back()
	var any := false
	for opt in last_option:
		if _dp(goal - opt, new):
			any = true
			break
	memo[[goal, options]] = any
	return any

static func _sorted(options: Array[Array]) -> bool:
	var last_arr := []
	for opt in options:
		var last := -1.0
		for o in opt:
			if o <= last:
				return false
			last = o
		if opt < last_arr:
			return false
		last_arr = opt
	return true

static func can_be_solved(goal: float, options: Array[Array]) -> bool:
	if memo.size() > 10000:
		push_warning("Options sum memo too large: %d" % memo.size())
		memo.clear()
	assert(_sorted(options))
	return _dp(goal, options)
