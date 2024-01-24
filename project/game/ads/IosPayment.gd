class_name IosPayment
extends Node

signal disable_ads()

const PURCHASE_ID := "TODO"
var api = null

func _init(api_) -> void:
	api = api_
	api.restore_purchases()

func _process(_dt: float) -> void:
	while api.get_pending_event_count() > 0:
		var event = api.pop_pending_event()
		if event.type == "purchase":
			if event.result == "ok" and event.product_id == PURCHASE_ID:
				disable_ads.emit()
				api.finish_transaction(PURCHASE_ID)
			else:
				print("Unknown purchase: %s" % event)
		if event.type == "restore":
			if event.result == "ok" and event.product_id == PURCHASE_ID:
				disable_ads.emit()
			else:
				print("Unknown restore: %s" % event)

func do_purchase() -> void:
	api.purchase({product_id = PURCHASE_ID})

static func setup() -> IosPayment:
	if Engine.has_singleton("InAppStore"):
		return IosPayment.new(Engine.get_singleton("InAppStore"))
	else:
		print("Unavailable iOS payments")
		return null
