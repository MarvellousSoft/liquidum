class_name PlatformPayment
extends Node

signal disable_ads()
signal purchased_section(section: int)

func start() -> void:
	GridModel.must_be_implemented()

func do_purchase_disable_ads() -> void:
	GridModel.must_be_implemented()

func do_purchase_section(_section: int) -> void:
	GridModel.must_be_implemented()
