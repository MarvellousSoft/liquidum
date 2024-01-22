extends Node

# Keep at least these many pixels available to show a banner ad
const BOTTOM_BUFFER_FOR_AD := 50

var _ad_view: AdView = null
var _big_ad: InterstitialAd = null

func _ready() -> void:
	if not Global.is_mobile:
		return
	MobileAds.set_ios_app_pause_on_background(true)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialization_complete
	MobileAds.initialize()

func show_big_ad(exit_ad: Callable) -> void:
	if not Global.is_mobile:
		exit_ad.call()
		return
	destroy_ads()
	var unit_id: String = ""
	if OS.get_name() == "Android":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/1033173712"
		else:
			# TODO: Get proper unit id
			unit_id = "ca-app-pub-3940256099942544/1033173712"
	elif OS.get_name() == "iOS":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/4411468910"
		else:
			# TODO: Get proper unit id
			unit_id = "ca-app-pub-3940256099942544/4411468910"
	if unit_id.is_empty():
		exit_ad.call()
		return
	var req := AdRequest.new()
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _big_ad_loaded.bind(exit_ad)
	callback.on_ad_failed_to_load = func(err):
		print("Ad failed to load: %s", err)
		exit_ad.call()
	InterstitialAdLoader.new().load(unit_id, req, callback)

func _big_ad_loaded(ad: InterstitialAd, exit_ad: Callable) -> void:
	_big_ad = ad
	var callback := FullScreenContentCallback.new()
	callback.on_ad_clicked = func(): print("Ad clicked")
	callback.on_ad_dismissed_full_screen_content = exit_ad
	callback.on_ad_failed_to_show_full_screen_content = func(err):
		print("Error showing fullscreen content: %s" % err)
		exit_ad.call()
	callback.on_ad_impression = func(): print("Ad impression")
	callback.on_ad_showed_full_screen_content = func(): print("Ad showed content")
	ad.full_screen_content_callback = callback
	ad.show()


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

func destroy_ads() -> void:
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null
	if _big_ad != null:
		_big_ad.destroy()
		_big_ad = null

func _get_black_bar_size() -> int:
	var w_size := DisplayServer.window_get_size()
	var shown_size := get_viewport().get_visible_rect() * get_viewport().get_screen_transform()
	var black_bar_size := (float(w_size.y) - shown_size.size.y) / 2.0
	# The above logic is wrong and needs fixing
	black_bar_size = 0.0
	return maxi(black_bar_size, 0)

func create_banner_ad() -> AdView:
	destroy_ads()
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
