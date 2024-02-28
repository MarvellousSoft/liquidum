extends Node

var impl: NotificationImpl
var enabled := false

enum Notifications {
	Daily = 1,
}

enum DailyStatus {
	NotUnlocked,
}

func _ready() -> void:
	impl = NotificationImpl.new()
	if impl.ln == null:
		enabled = false
	else:
		enabled = true
		add_child(impl)
		print(impl.isPermissionGranted())

