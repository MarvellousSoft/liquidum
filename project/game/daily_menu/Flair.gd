class_name Flair

# This should be very tiny
var name: String
var color: Color
var dark_mode_color: Color

func _init(name_: String, color_: Color, dark_mode_color_: Color) -> void:
	name = name_
	color = color_
	dark_mode_color = dark_mode_color_

static func _append_color(arr: PackedByteArray, c: Color) -> void:
	var offset := arr.size()
	arr.resize(offset + 4)
	arr.encode_u32(offset, c.to_rgba32())

static func encode(flair: Flair) -> PackedByteArray:
	if flair == null:
		flair = Flair.new("", Color.BLACK, Color.BLACK)
	var arr := PackedByteArray()
	var name_utf8 := flair.name.to_utf8_buffer()
	arr.append(name_utf8.size())
	if name_utf8.is_empty():
		return arr
	arr.append_array(name_utf8)
	Flair._append_color(arr, flair.color)
	Flair._append_color(arr, flair.dark_mode_color)
	return arr

static func decode(offset: int, arr: PackedByteArray) -> Flair:
	var sz := arr[offset]
	offset += 1
	if sz == 0:
		return null
	var name_ := arr.slice(offset, offset + sz).get_string_from_utf8()
	offset += sz
	var color_ := Color.hex(arr.decode_u32(offset))
	offset += 4
	var dark_mode_color_ := Color.hex(arr.decode_u32(offset))
	return Flair.new(name_, color_, dark_mode_color_)
