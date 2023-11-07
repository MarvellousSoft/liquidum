class_name Grid

static func must_be_implemented() -> Variant:
	assert(false, "Must be implemented")
	return null

static func create(rows: int, cols: int) -> Grid:
	return GridImpl.new(rows, cols)


enum Corner { BottomLeft, BottomRight, TopLeft, TopRight }
enum Side { Top, Right, Bottom, Left }
# Major diagonal = \, Minor diagonal = /
enum Diagonal { Major, Minor }

class Cell:
	func water_full() -> bool:
		return Grid.must_be_implemented()
	# If full of water, all Corners return true
	func water_at(_corner: Corner) -> bool:
		return Grid.must_be_implemented()
	# Counts the sides of the grid as walls
	func wall_at(_side: Side) -> bool:
		return Grid.must_be_implemented()
	func diag_wall_at(_diag: Diagonal) -> bool:
		return Grid.must_be_implemented()

func rows() -> int:
	return must_be_implemented()

func cols() -> int:
	return must_be_implemented()

# 0-indexed
func get_cell(_i: int, _j: int) -> Cell:
	return must_be_implemented()

# Checks walls in the grid without accessing cells directly
func wall_at(_i: int, _j: int, _side: Side) -> bool:
	return must_be_implemented()

# -1 if there's no hint. 0.5 for diagonals
func hint_row(i: int) -> float:
	return must_be_implemented()

# -1 if there's no hint. 0.5 for diagonals
func hint_col(j: int) -> float:
	return must_be_implemented()
