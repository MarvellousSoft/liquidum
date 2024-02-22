class_name SteamPlaytimeTracker
extends Node

# Name without the _secs or _total suffix
var stats: Array[String] = []

func _ready() -> void:
	if not SteamManager.enabled:
		set_process(false)

var time_to_add := 0.0

func _process(dt: float) -> void:
	time_to_add += dt

func set_tracking(on: bool) -> void:
	set_process(on)

func flush() -> void:
	if not SteamManager.enabled or not SteamManager.stats_received:
		return
	for stat in stats:
		var stat_name := stat + "_secs"
		var prev: float = SteamManager.steam.getStatFloat(stat_name)
		SteamManager.steam.setStatFloat(stat_name, prev + time_to_add)
		var stat_tot_name := stat + "_total"
		if SteamManager.steam.getStatInt(stat_tot_name) == 0:
			SteamManager.steam.setStatInt(stat_tot_name, 1)
	time_to_add = 0


func _exit_tree() -> void:
	flush()

