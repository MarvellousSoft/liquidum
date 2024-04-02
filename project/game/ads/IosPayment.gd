class_name IosPayment
extends PlatformPayment

const DISABLE_ADS_ID := "disable_ads"
var api = null
var dlc_ids: Array[String] = []

func _init(api_) -> void:
	api = api_
	var extra_section := 1
	while ExtraLevelLister.has_section(extra_section):
		var id := ExtraLevelLister.ios_payment(extra_section)
		if id != "":
			dlc_ids.append(id)
		extra_section += 1

func start() -> void:
	api.restore_purchases()


func _process(_dt: float) -> void:
	while api.get_pending_event_count() > 0:
		var event = api.pop_pending_event()
		if event.type == "purchase":
			if event.result == "ok" and event.product_id == DISABLE_ADS_ID:
				disable_ads.emit()
				api.finish_transaction(DISABLE_ADS_ID)
			elif event.result == "ok" and event.product_id in dlc_ids:
				api.finish_transaction(event.product_id)
				dlc_purchased.emit(event.product_id)
			else:
				print("Unknown purchase: %s" % event)
		if event.type == "restore":
			if event.result == "ok" and event.product_id == DISABLE_ADS_ID:
				disable_ads.emit()
			else:
				print("Unknown restore: %s" % event)

func do_purchase_disable_ads() -> void:
	api.purchase({product_id = DISABLE_ADS_ID})

func do_purchase_dlc(id: String) -> void:
	api.purchase({product_id = id})

static func setup() -> IosPayment:
	if Engine.has_singleton("InAppStore"):
		return IosPayment.new(Engine.get_singleton("InAppStore"))
	else:
		print("Unavailable iOS payments")
		return null
