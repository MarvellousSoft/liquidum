class_name OutlineLabelConvert
extends Label

func _ready() -> void:
	call_deferred("put_inside_group")

func put_inside_group() -> void:
	var had_uniq := unique_name_in_owner
	var group := preload("res://game/ui/OutlineLabel.tscn").instantiate()
	add_sibling(group)
	reparent(group)
	if had_uniq:
		unique_name_in_owner = true
