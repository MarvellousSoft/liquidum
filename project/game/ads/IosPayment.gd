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

# Apple does not recommend restoring purchases all the time, let's store purchases to a file and
# just restore if a button is pressed.
# Refunds are not handled, don't tell anyone.
const PURCHASES_FILE := "ios_purchases"

func load_purchases() -> Array[String]:
	var arr: Array[String] = []
	var data = FileManager._load_json_data("res://", PURCHASES_FILE, false) 
	if data != null and data is Array:
		arr.assign(data)
	return arr

func save_purchase(id: String) -> void:
	var arr := load_purchases()
	if arr.find(id) == -1:
		arr.append(id)
		FileManager._save_json_data("res://", PURCHASES_FILE, arr)

func start() -> void:
	print("Restoring iOS in app purchases")
	var result = api.request_product_info({product_ids = dlc_ids + [DISABLE_ADS_ID]})
	if result != OK:
		print("Error requesting details: %s" % [result])
	var arr := load_purchases()
	for id in arr:
		if id == DISABLE_ADS_ID:
			disable_ads.emit()
		else:
			dlc_purchased.emit(id)
	disable_ads.connect(save_purchase.bind(DISABLE_ADS_ID))
	dlc_purchased.connect(save_purchase)

func restore_purchases() -> void:
	var result = api.restore_purchases()
	if result != OK:
		print("Error restoring purchases: %s" % [result])


func _process(_dt: float) -> void:
	while api.get_pending_event_count() > 0:
		var event = api.pop_pending_event()
		print("Apple IAP event: %s" % [event])
		if event.type == "purchase":
			if event.result == "ok" and event.product_id == DISABLE_ADS_ID:
				print("Finished purchasing disable ads" % [event.product_id])
				disable_ads.emit()
				api.finish_transaction(DISABLE_ADS_ID)
			elif event.result == "ok" and event.product_id in dlc_ids:
				print("Finished purchasing DLC with id %s" % [event.product_id])
				api.finish_transaction(event.product_id)
				dlc_purchased.emit(event.product_id)
			else:
				print("Unknown purchase: %s" % event)
		if event.type == "restore":
			if event.result == "ok" and event.product_id == DISABLE_ADS_ID:
				disable_ads.emit()
			elif event.result == "ok" and event.product_id in dlc_ids:
				dlc_purchased.emit(event.product_id)
			else:
				print("Unknown restore: %s" % event)

func do_purchase_disable_ads() -> void:
	do_purchase_dlc(DISABLE_ADS_ID)

func do_purchase_dlc(id: String) -> void:
	var result = api.purchase({product_id = id})
	if result != OK:
		print("Error purchasing %s: %s" % [id, result])


static func setup() -> IosPayment:
	if Engine.has_singleton("InAppStore"):
		return IosPayment.new(Engine.get_singleton("InAppStore"))
	else:
		print("Unavailable iOS payments")
		return null
