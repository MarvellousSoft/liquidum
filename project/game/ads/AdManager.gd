extends Node

# Keep at least these many pixels available to show a banner ad
const BOTTOM_BUFFER_FOR_AD := 50

signal big_ad_loaded()
signal ads_disabled()

var _ad_view: AdView = null
var _big_ad: InterstitialAd = null
var _loading_big_ad: bool = false
var disabled := false
var payment: PlatformPayment = null

func _ready() -> void:
	if not Global.is_mobile:
		return
	if OS.get_name() == "Android":
		payment = AndroidPayment.setup()
	elif OS.get_name() == "iOS":
		payment = IosPayment.setup()
	if payment != null:
		payment.disable_ads.connect(_on_disable_ads)
		add_child(payment)
		payment.start()
	MobileAds.set_ios_app_pause_on_background(true)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialization_complete
	MobileAds.initialize(listener)

func buy_ad_removal() -> void:
	if payment != null:
		payment.do_purchase_disable_ads()

func _on_disable_ads() -> void:
	print("Ads are disabled")
	disabled = true
	ads_disabled.emit()

func preload_big_ad() -> void:
	destroy_big_ad()
	if disabled:
		return
	var unit_id: String = ""
	if OS.get_name() == "Android":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/1033173712"
		else:
			unit_id = "ca-app-pub-8067794432001522/7836458492"
	elif OS.get_name() == "iOS":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/4411468910"
		else:
			unit_id = "ca-app-pub-8067794432001522/4513179203"
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
	if disabled:
		return
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
	if not Global.is_mobile or disabled:
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
			unit_id = "ca-app-pub-8067794432001522/9245796985"
	elif OS.get_name() == "iOS":
		if OS.is_debug_build():
			unit_id = "ca-app-pub-3940256099942544/2934735716"
		else:
			unit_id = "ca-app-pub-8067794432001522/6860937108"
	var size := AdSize.get_portrait_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	var black_bar_h := _get_black_bar_size()
	if size.height < black_bar_h:
		size.height = black_bar_h
	elif size.height - black_bar_h > BOTTOM_BUFFER_FOR_AD:
		size.height = BOTTOM_BUFFER_FOR_AD + black_bar_h
	_ad_view = AdView.new(unit_id, size, AdPosition.Values.BOTTOM)
	return _ad_view

func _on_initialization_complete(initialization_status: InitializationStatus) -> void:
	print("MobileAds initialization complete")
	for key in initialization_status.adapter_status_map:
		var adapterStatus : AdapterStatus = initialization_status.adapter_status_map[key]
		prints(
			"Key:", key, 
			"Latency:", adapterStatus.latency, 
			"Initialization Status:", adapterStatus.initialization_status, 
			"Description:", adapterStatus.description
		)
