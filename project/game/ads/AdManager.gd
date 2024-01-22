extends Node

# Keep at least these many pixels available to show a banner ad
const BOTTOM_BUFFER_FOR_AD := 50

signal big_ad_loaded()

var _ad_view: AdView = null
var _big_ad: InterstitialAd = null
var _loading_big_ad: bool = false

func _ready() -> void:
	if not Global.is_mobile:
		return
	MobileAds.set_ios_app_pause_on_background(true)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialization_complete
	MobileAds.initialize()

# MUST be called before show_big_ad
func preload_big_ad() -> void:
	destroy_big_ad()
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
	var req := AdRequest.new()
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _big_ad_loaded
	callback.on_ad_failed_to_load = func(err):
		print("Ad failed to load: %s", err)
		_loading_big_ad = false
		big_ad_loaded.emit()
	_loading_big_ad = true
	InterstitialAdLoader.new().load(unit_id, req, callback)

func show_big_ad(exit_ad: Callable) -> void:
	if _big_ad == null and not _loading_big_ad:
		preload_big_ad()
	if _loading_big_ad:
		await big_ad_loaded
	if _big_ad == null:
		exit_ad.call()
		return
	var callback := FullScreenContentCallback.new()
	callback.on_ad_clicked = func(): print("Ad clicked")
	callback.on_ad_dismissed_full_screen_content = exit_ad
	callback.on_ad_failed_to_show_full_screen_content = func(err):
		print("Error showing fullscreen content: %s" % err)
		exit_ad.call()
	callback.on_ad_impression = func(): print("Ad impression")
	callback.on_ad_showed_full_screen_content = func(): print("Ad showed content")
	_big_ad.full_screen_content_callback = callback
	_big_ad.show()
	

func _big_ad_loaded(ad: InterstitialAd) -> void:
	_big_ad = ad
	_loading_big_ad = false
	big_ad_loaded.emit()

func show_bottom_ad() -> void:
	if not Global.is_mobile:
		return
	var ad := create_bottom_ad()
	var req := AdRequest.new()
	var listener := AdListener.new()
	listener.on_ad_clicked = func(): print("Add clicked")
	listener.on_ad_closed = func(): print("Ad closed")
	listener.on_ad_failed_to_load = func(err): print("Ad failed to load: %s", err)
	listener.on_ad_impression = func(): print("Ad impression")
	listener.on_ad_loaded = func(): print("Ad loaded")
	ad.ad_listener = listener
	ad.load_ad(req)

func destroy_bottom_ad() -> void:
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null

func destroy_big_ad() -> void:
	if _big_ad != null:
		_big_ad.destroy()
		_big_ad = null
		_loading_big_ad = false

func _get_black_bar_size() -> int:
	var w_size := DisplayServer.window_get_size()
	var shown_size := get_viewport().get_visible_rect() * get_viewport().get_screen_transform()
	var black_bar_size := (float(w_size.y) - shown_size.size.y) / 2.0
	# The above logic is wrong and needs fixing
	black_bar_size = 0.0
	return maxi(floori(black_bar_size), 0)

func create_bottom_ad() -> AdView:
	destroy_bottom_ad()
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
