extends CanvasLayer


func _ready():
	BlueFilter.set_value(float(Profile.get_option("blue_filter"))/100.0)


#Expects a value between 0 and 1
func set_value(new_value: float) -> void:
	%BG.material.set_shader_parameter(&"strength", new_value)
