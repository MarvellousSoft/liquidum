class_name Flair

var id: String
# This should be very tiny
var name: String
var color: Color

func _init(id_: String, name_: String, color_: Color) -> void:
	id = id_
	name = name_
	color = color_

static func _append_color(arr: PackedByteArray, c: Color) -> void:
	var offset := arr.size()
	arr.resize(offset + 4)
	arr.encode_u32(offset, c.to_rgba32())

static func encode(flair: Flair) -> PackedByteArray:
	if flair == null:
		flair = Flair.new("","", Color.BLACK)
	var arr := PackedByteArray()
	var name_utf8 := flair.name.to_utf8_buffer()
	arr.append(name_utf8.size())
	if name_utf8.is_empty():
		return arr
	arr.append_array(name_utf8)
	Flair._append_color(arr, flair.color)
	return arr

static func decode(offset: int, arr: PackedByteArray) -> Flair:
	var sz := arr[offset]
	offset += 1
	if sz == 0:
		return null
	var id_ := arr.slice(offset, offset + sz).get_string_from_utf8()
	offset += sz
	var name_ := arr.slice(offset, offset + sz).get_string_from_utf8()
	offset += sz
	var color_ := Color.hex(arr.decode_u32(offset))
	offset += 4
	return Flair.new(id_, name_, color_)
