class_name SteamFlair

var id: int

func _init(id_: int) -> void:
	id = id_

static func encode(flair: SteamFlair) -> PackedByteArray:
	var fid: int = flair.id if flair != null else -1
	var arr := PackedByteArray()
	arr.encode_s32(0, fid)
	return arr

static func decode(offset: int, arr: PackedByteArray) -> SteamFlair:
	var id_: int = arr.decode_s32(offset)
	return SteamFlair.new(id_)

static func old_flair_decode_text(offset: int, arr: PackedByteArray) -> String:
	var sz := arr[offset]
	offset += 1
	if sz == 0:
		return ""
	return arr.slice(offset, offset + sz).get_string_from_utf8()