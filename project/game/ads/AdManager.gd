extends Node

# Keep at least these many pixels available to show a banner ad
const BOTTOM_BUFFER_FOR_AD := 50

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
	var ad := create_banner_ad()
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

func _get_black_bar_size() -> int:
	var w_size := DisplayServer.window_get_size()
	var shown_size := get_viewport().get_visible_rect() * get_viewport().get_screen_transform()
	var black_bar_size := (float(w_size.y) - shown_size.size.y) / 2.0
	# The above logic is wrong and needs fixing
	black_bar_size = 0.0
	return maxi(black_bar_size, 0)

func create_banner_ad() -> AdView:
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
	var size := AdSize.get_portrait_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	var black_bar_h := _get_black_bar_size()
	if size.height < black_bar_h:
		size.height = black_bar_h
	elif size.height - black_bar_h > BOTTOM_BUFFER_FOR_AD:
		size.height = BOTTOM_BUFFER_FOR_AD + black_bar_h
		
	_ad_view = AdView.new(unit_id, size, AdPosition.Values.BOTTOM)
	return _ad_view

func _on_initialization_complete(initialization_status: InitializationStatus) -> void:
	print("Ads initialization complete: %s" % initialization_status.adapter_status_map)
