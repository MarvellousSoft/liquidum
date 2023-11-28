extends Node

# TODO: Figure this out some other way
var enabled := false
const APP_ID := 2716690


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	var res := Steam.steamInit()
	print("Steam init: %s" % res)
	print("Steam running: %s" % Steam.isSteamRunning())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Steam.steamShutdown()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_dt: float) -> void:
	Steam.run_callbacks()
