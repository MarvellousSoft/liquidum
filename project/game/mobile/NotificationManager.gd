extends Node

var impl: NotificationImpl
var enabled: bool:
	get: return impl != null and impl.ln != null

var go_to_settings_if_failed := false

func _ready() -> void:
	if not Global.is_mobile:
		return
	impl = NotificationImpl.new()
	add_child(impl)
	if impl.ln == null:
		print("Notification lib is disabled.")
	else:
		print("Notification lib is enabled. Permission granted = %s" % [permission_granted()])
		Profile.daily_notification_changed.connect(_on_daily_notif_changed)
		impl.on_permission_request_completed.connect(_on_permission_completed)
		if OS.get_name() == "iOS" and Profile.get_option("daily_notification") == Profile.DailyStatus.Enabled:
			# iOS can't schedule weekly notifications, let's do it manually every time and
			# if the user goes away for a week it disappears
			for i in 7:
				impl.cancel(i + 1)
			do_add_daily_notif()

func permission_granted() -> bool:
	return impl.isPermissionGranted()

func _on_daily_notif_changed(on: bool) -> void:
	if on:
		if permission_granted():
			do_add_daily_notif()
		else:
			go_to_settings_if_failed = true
			impl.requestPermission()
	else:
		for i in 7:
			impl.cancel(i + 1)

func _on_permission_completed() -> void:
	var granted := permission_granted()
	print("Permission completed: %s" % [granted])
	if granted:
		do_add_daily_notif()
	else:
		if go_to_settings_if_failed:
			go_to_settings_if_failed = false
			Profile.set_option("daily_notification", Profile.DailyStatus.Disabled)
			Profile.daily_notification_changed.emit(false)
			impl.openAppSetting()

func _notif_title(weekday: Time.Weekday) -> String:
	return tr("DAILY_NOTIF_TITLE") % [tr(DailyButton._level_name_tr(weekday)), DailyButton.WEEKDAY_EMOJI[weekday]]

func _notif_desc(_weekday: Time.Weekday) -> String:
	return tr("DAILY_NOTIF_DESC")

func do_add_daily_notif() -> void:
	for day in 7:
		if OS.get_name() == "iOS":
			impl.show(_notif_title(day), _notif_desc(day), impl._generate_weekly_notify_interval(day, 8, 0), day + 1)
		else:
			impl.showWeekly(_notif_title(day), _notif_desc(day), day, 8, 0, day + 1)
