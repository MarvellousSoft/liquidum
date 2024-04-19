class_name SteamFlair

var id: int
var extra_flairs: int

func _init(id_: int, extra_flairs_: int) -> void:
	id = id_
	extra_flairs = extra_flairs_

static func encode(flair: SteamFlair) -> PackedByteArray:
	if flair == null:
		flair = SteamFlair.new(-1, 0)
	var arr := PackedByteArray()
	arr.resize(6)
	arr.encode_s32(0, flair.id)
	arr.encode_u16(4, flair.extra_flairs)
	return arr

static func decode(offset: int, arr: PackedByteArray) -> SteamFlair:
	var id_: int = arr.decode_s32(offset)
	if id_ == -1:
		return null
	var extra_: int = arr.decode_u16(offset + 4)
	return SteamFlair.new(id_, extra_)

static func old_flair_decode_text(offset: int, arr: PackedByteArray) -> String:
	var sz := arr[offset]
	offset += 1
	if sz == 0:
		return ""
	return arr.slice(offset, offset + sz).get_string_from_utf8()

const MAX_FLAIRS = 1000000

func encode_to_int() -> int:
	if id == -1:
		return -1
	return extra_flairs * MAX_FLAIRS + id

static func decode_from_int(num: int) -> SteamFlair:
	if num == -1:
		return null
	return SteamFlair.new(
		num % MAX_FLAIRS,
		num / MAX_FLAIRS
	)	