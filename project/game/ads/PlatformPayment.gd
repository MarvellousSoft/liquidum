class_name PlatformPayment
extends Node

signal disable_ads()
signal dlc_purchased(payment_id: String)

func start() -> void:
	GridModel.must_be_implemented()

func do_purchase_disable_ads() -> void:
	GridModel.must_be_implemented()

func do_purchase_dlc(_payment_id: String) -> void:
	GridModel.must_be_implemented()
