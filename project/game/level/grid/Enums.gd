# These enums are made to be used interchangeably because they always have the same values.
# So be very careful when changing the order of elements.
# If necessary for type checking, you can cast between them, like:
# call_corner(corner as E.Corner)

enum { Top = 1, Right, Bottom, Left, TopLeft, TopRight, BottomRight, BottomLeft, Inc, Dec, Single, None }

enum Side { Top = 1, Right, Bottom, Left }
enum Corner { TopLeft = 5, TopRight, BottomRight, BottomLeft }
# Dec diagonal = \, Inc diagonal = /
enum Diagonal { Inc = 9, Dec }

enum CellType { IncDiag = 9, DecDiag, Single}
enum Walls {Top = 1, Right, Bottom, Left, IncDiag = 9, DecDiag}
enum Waters {TopLeft = 5, TopRight, BottomRight, BottomLeft, Single = 11, None}
