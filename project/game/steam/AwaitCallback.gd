# For awaiting a callback with exactly one parameter
class_name AwaitCallback

signal called(val: Variant)

func callback(val: Variant) -> void:
	called.emit(val)
