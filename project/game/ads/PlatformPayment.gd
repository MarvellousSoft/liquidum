class_name PlatformPayment
extends Node

signal disable_ads()
signal dlc_purchased(payment_id: String)

var purchased: Array[String] = []

func _init() -> void:
	disable_ads.connect(_register_purchase.bind("disable_ads"))
	dlc_purchased.connect(_register_purchase)

func _register_purchase(id: String) -> void:
	if purchased.find(id) == -1:
		purchased.append(id)

func start() -> void:
	GridModel.must_be_implemented()

func purchased_ids() -> Array[String]:
	return GridModel.must_be_implemented()

func do_purchase_disable_ads() -> void:
	GridModel.must_be_implemented()

func do_purchase_dlc(_payment_id: String) -> void:
	await GridModel.must_be_implemented()
