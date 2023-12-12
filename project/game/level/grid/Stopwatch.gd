class_name Stopwatch
var start: int

func _init() -> void:
	start = Time.get_ticks_usec()

const USEC_TO_SEC: float = 1e6

# Seconds elapsed since start. Does not reset the stopwatch.
func elapsed() -> float:
	return float(Time.get_ticks_usec() - start) / USEC_TO_SEC

# Seconds elapsed since start. Resets the stopwatch.
func elapsed_reset() -> float:
	var new := Time.get_ticks_usec()
	var ans := float(new - start) / USEC_TO_SEC
	start = new
	return ans

func print_reset(name: String) -> void:
	var time := elapsed_reset()
	print("%s = %.2fs" % [name, time])
