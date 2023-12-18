extends Node

# Name without the _secs or _total suffix
var stats: Array[String] = []

func _ready() -> void:
	if not SteamManager.enabled:
		set_process(false)

var time_to_add := 0.0

func _process(dt: float) -> void:
	# TODO: Pause if on pause screen
	time_to_add += dt

func flush() -> void:
	if not SteamManager.enabled or not SteamManager.stats_received:
		return
	for stat in stats:
		var stat_name := stat + "_secs"
		var prev := Steam.getStatFloat(stat_name)
		Steam.setStatFloat(stat_name, prev + time_to_add)
		var stat_tot_name := stat + "_total"
		if Steam.getStatInt(stat_tot_name) == 0:
			Steam.setStatInt(stat_tot_name, 1)
	time_to_add = 0

func _enter_tree() -> void:
	print("Tracking playtime for %s" % [stats])

func _exit_tree() -> void:
	flush()
	print("Stopped tracking playtime for %s" % [stats])
