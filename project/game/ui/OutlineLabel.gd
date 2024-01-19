extends CanvasGroup

var text: String :
	get:
		return $Label.text
	set(x):
		$Label.text = x


func _process(dt):
	var a := 1.0
	var n := get_parent()
	while n != null:
		if n.get("modulate") != null:
			a *= n.modulate.a
		else:
			break
		n = n.get_parent()
	self_modulate.a = a
