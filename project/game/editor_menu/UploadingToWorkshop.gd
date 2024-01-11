extends CanvasLayer

@onready var Update: Timer = $Update
@onready var Progress: Range = %ProgressBar

var update_handle: int = 0

func start() -> void:
	update_handle = 0
	Update.start()
	Progress.max_value = 100
	Progress.value = 0
	show()

func stop() -> void:
	Update.stop()
	hide()

func _on_update_timeout():
	if update_handle == 0 or not SteamManager.enabled:
		return
	var ret: Dictionary = SteamManager.steam.getItemUpdateProgress(update_handle)
	if ret.status == 0:
		return
	var pct := (float(ret.status) / 6.0) + (1.0 / 6.0) * (float(ret.processed) / float(ret.total))
	Progress.value = 100 * pct
