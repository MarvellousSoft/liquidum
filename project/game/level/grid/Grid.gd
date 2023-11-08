class_name GridModel

static func must_be_implemented() -> Variant:
	assert(false, "Must be implemented")
	return null



class CellModel:
	func water_full() -> bool:
		return GridModel.must_be_implemented()
	# If full of water, all Corners return true
	func water_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	# When user marks a tile definitely doesn't contain waters
	func air_full() -> bool:
		return GridModel.must_be_implemented()
	func air_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	func block_full() -> bool:
		return GridModel.must_be_implemented()
	func block_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	# Counts the sides of the grid as walls
	func wall_at(_side: E.Side) -> bool:
		return GridModel.must_be_implemented()
	func diag_wall_at(_diag: E.Diagonal) -> bool:
		return GridModel.must_be_implemented()
	# Puts water in the given diagonal and floods
	func put_water(_corner: E.Corner) -> void:
		return GridModel.must_be_implemented()
	# Puts air in the given diagonal
	func put_air(_corner: E.Corner) -> void:
		return GridModel.must_be_implemented()
	func remove_water_or_air(_corner: E.Corner) -> void:
		return GridModel.must_be_implemented()

func rows() -> int:
	return GridModel.must_be_implemented()

func cols() -> int:
	return GridModel.must_be_implemented()

# 0-indexed
func get_cell(_i: int, _j: int) -> CellModel:
	return GridModel.must_be_implemented()

# Checks walls in the grid without accessing cells directly
func wall_at(_i: int, _j: int, _side: E.Side) -> bool:
	return GridModel.must_be_implemented()

# -1 if there's no hint. 0.5 for diagonals
func hint_row(_i: int) -> float:
	return GridModel.must_be_implemented()

func set_hint_row(_i: int, _v: float) -> void:
	return GridModel.must_be_implemented()

# -1 if there's no hint. 0.5 for diagonals
func hint_col(_j: int) -> float:
	return GridModel.must_be_implemented()

func set_hint_col(_j: int, _v: float) -> void:
	return GridModel.must_be_implemented()

# Is this a valid solution?
func are_hints_satisfied() -> bool:
	return GridModel.must_be_implemented()

func count_water_row(_i: int) -> float:
	return GridModel.must_be_implemented()

func count_water_col(_j: int) -> float:
	return GridModel.must_be_implemented()

# Replace this grid with the one loaded from the string
# The string should be a 2Nx2M grid, each cell represented by 4 characters
# 12
# 34
# 1 and 2 are the contents on both left and right sides.
# - w: water
# - x: air (not necessary for the solution, just for tracking where there's no water)
# - #: block (can't have either water or air)
# - .: nothing
# 3 is the left and bottom wall information.
# - |: left wall only
# - _: bottom wall only
# - L: bottom and left wall
# - .: no left or bottom walls
# 4 is the diagonal wall information.
# - ╲: major diagonal wall (fancy unicode ╲ to avoid escaping on strings)
# - /: minor diagonal wall
# - .: no diagonal wall
# If hints are desired, the string should be a (2N+1)x(2M+1) grid, and the first row and
# first column should contain the hints multiplied by two. The hints are integers, up to
# two characters long. (That's because hints in the actual game increment by 0.5)
# The other characters must be '.', and any row or column may not have a hint.
# (If the row hint has two characters, it must be one per line.)
# Example:
# wwwx
# L../
# #..w
# L._╲
# Example with hints:
# ...1.3.
# 2......
# .|╲_/./
# 2......
# .L._.L.
func load_from_str(_s: String) -> void:
	return GridModel.must_be_implemented()

# Converts to string format as described on `load_from_str`
func to_str() -> String:
	return GridModel.must_be_implemented()

# Undo the latest changes. Returns true if it was possible to do so.
func undo() -> bool:
	return GridModel.must_be_implemented()

# Redo the latest undone changes
func redo() -> bool:
	return GridModel.must_be_implemented()

# TODO: Not implemented
# Whether all water and air is in correct places
func is_flooded() -> bool:
	return GridModel.must_be_implemented()
