class_name DumbMutex
# Very simple mutex, which is async and not reentrant (important!)
# Should be used only on async contexts

var locked := false

func lock() -> void:
	while locked:
		await Global.wait(0.1)
	locked = true

func unlock() -> void:
	assert(locked)
	locked = false
