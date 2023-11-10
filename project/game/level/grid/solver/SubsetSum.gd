class_name SubsetSum

static var memo: Dictionary = {}

static func _dp(goal: float, numbers: Array[float]) -> bool:
	if goal < 0:
		return false
	if goal == 0:
		return true
	if numbers.is_empty():
		return false
	if memo.has([goal, numbers]):
		return memo.get([goal, numbers])
	var new: Array[float] = numbers.duplicate()
	var last: float = new.pop_back()
	# Try to use the last number
	if _dp(goal - last, new):
		memo[[goal, numbers]] = true
	# Don't use it
	elif _dp(goal, new):
		memo[[goal, numbers]] = true
	else:
		memo[[goal, numbers]] = false
	return memo[[goal, numbers]]


# The numbers are all floats multiples of 0.5
static func can_be_solved(goal: float, numbers: Array[float]) -> bool:
	if memo.size() > 10000:
		push_warning("Subset sum memo too large: %d" % memo.size())
		memo.clear()
	numbers.sort()
	return _dp(goal, numbers)
