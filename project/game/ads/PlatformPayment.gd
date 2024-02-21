class_name PlatformPayment
extends Node

signal disable_ads()

func start() -> void:
	GridModel.must_be_implemented()

func do_purchase() -> void:
	GridModel.must_be_implemented()
