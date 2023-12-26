extends Node
# These enums are made to be used interchangeably because they always have the same values.
# So be very careful when changing the order of elements.
# If necessary for type checking, you can cast between them, like:
# call_corner(corner as E.Corner)

enum { Top = 1, Right, Bottom, Left, TopLeft, TopRight, BottomRight, BottomLeft, Inc, Dec, Single, None }

enum Side { Top = 1, Right, Bottom, Left }
enum Corner { TopLeft = 5, TopRight, BottomRight, BottomLeft }
# Dec diagonal = \, Inc diagonal = /
enum Diagonal { Inc = 9, Dec }

enum CellType { IncDiag = 9, DecDiag, Single }
enum Walls { Top = 1, Right, Bottom, Left, IncDiag = 9, DecDiag }
enum Waters { TopLeft = 5, TopRight, BottomRight, BottomLeft, Single = 11 }

enum MouseDragState { None, Water, NoWater, Boat, Wall, Block, RemoveWater, RemoveNoWater, RemoveBoat, RemoveWall, RemoveBlock }

enum BrushMode { Water, NoWater, Boat, Wall, Block }

enum HintContent { Water, Boat }
enum HintType { Hidden, Together, Separated, Zero }
enum HintStatus { Normal, Wrong, Satisfied }

func corner_is_left(corner: E.Corner) -> bool:
	return corner == Corner.TopLeft or corner == Corner.BottomLeft
func corner_is_top(corner: E.Corner) -> bool:
	return corner == Corner.TopLeft or corner == Corner.TopRight
func corner_is_side(corner: E.Corner, side: E.Side) -> bool:
	match side:
		E.Left:
			return corner_is_left(corner)
		E.Right:
			return not corner_is_left(corner)
		E.Top:
			return corner_is_top(corner)
		E.Bottom:
			return not corner_is_top(corner)
	assert(false, "Invalid side")
	return false
func corner_to_diag(corner: E.Corner) -> E.Diagonal:
	if corner == E.Corner.BottomLeft or corner == E.Corner.TopRight:
		return E.Diagonal.Dec
	else:
		return E.Diagonal.Inc
func diag_to_corner(cell: E.CellType, side: E.Side) -> E.Corner:
	if cell == E.CellType.IncDiag:
		match side:
			E.Side.Top, E.Side.Left:
				return E.Corner.TopLeft
			E.Side.Bottom, E.Side.Right:
				return E.Corner.BottomRight
	else: # DecDiag or Single
		match side:
			E.Side.Top, E.Side.Right:
				return E.Corner.TopRight
			E.Side.Bottom, E.Side.Left:
				return E.Corner.BottomLeft
	assert(false, "Invalid side")
	return E.Corner.TopLeft
func waters_size(waters: E.Waters) -> float:
	match waters:
		E.Waters.Single:
			return 1.0
		_:
			return 0.5
