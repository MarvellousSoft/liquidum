extends Node

var _ad_view: AdView = null

func _ready() -> void:
	if not Global.is_mobile:
		return
	MobileAds.set_ios_app_pause_on_background(true)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialization_complete
	MobileAds.initialize()

func show_ad_bottom() -> void:
	if not Global.is_mobile:
		return
	var ad := create_add_view()
	var req := AdRequest.new()
	var listener := AdListener.new()
	listener.on_ad_clicked = func(): print("Add clicked")
	listener.on_ad_closed = func(): print("Ad closed")
	listener.on_ad_failed_to_load = func(err): print("Ad failed to load: %s", err)
	listener.on_ad_impression = func(): print("Ad impression")
	listener.on_ad_loaded = func(): print("Ad loaded")
	ad.ad_listener = listener
	ad.load_ad(req)

func destroy_ad_view() -> void:
	_ad_view.destroy()
	_ad_view = null

func create_add_view() -> AdView:
	if _ad_view != null:
		destroy_ad_view()
	var unit_id: String
	if OS.get_name() == "Android":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/6300978111"
		else:
			# TODO: Get proper unit id
			unit_id = "ca-app-pub-3940256099942544/6300978111"
	elif OS.get_name() == "iOS":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/2934735716"
		else:
			# TODO: Get proper unit id
			unit_id = "ca-app-pub-3940256099942544/2934735716"
	_ad_view = AdView.new(unit_id, AdSize.BANNER, AdPosition.Values.BOTTOM)
	return _ad_view

func _on_initialization_complete(initialization_status: InitializationStatus) -> void:
	print("Ads initialization complete: %s" % initialization_status.adapter_status_map)
