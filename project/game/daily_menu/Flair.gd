class_name Flair

# This should be very tiny
var name: String
var color: Color
var dark_mode_color: Color

func _init(name_: String, color_: Color, dark_mode_color_: Color) -> void:
	name = name_
	color = color_
	dark_mode_color = dark_mode_color_

func write_to_arr(arr: PackedInt32Array) -> void:
	if name == "":
		return
	arr.append_array(name.to_utf8_buffer().to_int32_array())
	arr.append(color.to_rgba32())
	arr.append(dark_mode_color.to_rgba32())

static func from_arr(arr: PackedInt32Array) -> Flair:
	if arr.is_empty():
		return null
	var dark_mode_color_ := Color.hex(arr[-1])
	arr.remove_at(-1)
	var color_ := Color.hex(arr[-1])
	arr.remove_at(-1)
	var name_ := arr.to_byte_array().get_string_from_utf8()
	return Flair.new(name_, color_, dark_mode_color_)
