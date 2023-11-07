extends Cell

const DIAGONAL_BUTTON_MASK = preload("res://assets/images/ui/diagonal_button_mask.png")

signal pressed

@onready var Waters = {
	"s" : $Waters/Single,
	"tl" : $Waters/TopLeft,
	"tr" : $Waters/TopRight,
	"bl" : $Waters/BottomLeft,
	"br" : $Waters/BottomRight,
}
@onready var Buttons = {
	"s" : $Buttons/Single,
	"tl" : $Buttons/TopLeft,
	"tr" : $Buttons/TopRight,
	"bl" : $Buttons/BottomLeft,
	"br" : $Buttons/BottomRight,
}
@onready var Hints = {
	"dec": $DiagHints/Dec,
	"inc": $DiagHints/Inc,
}
@onready var Walls = {
	"top": $Walls/Top,
	"right": $Walls/Right,
	"bottom": $Walls/Bottom,
	"left":$Walls/Left,
	"dec": $Walls/DecDiag,
	"inc": $Walls/IncDiag,
}

var row : int
var column : int


func setup(type : Cell.TYPES, i : int, j : int) -> void:
	row = i
	column = j
	for water in Waters.values():
		water.hide()
	for buttons in Buttons.values():
		buttons.hide()
	for hint in Hints.values():
		hint.hide()
	for wall in Walls.values():
		wall.hide()
	match type:
		Cell.TYPES.SINGLE:
			Buttons.s.show()
		Cell.TYPES.INC_DIAG:
			Buttons.tl.show()
			Buttons.br.show()
			set_wall(Cell.WALLS.INC_DIAG)
		Cell.TYPES.DEC_DIAG:
			Buttons.tr.show()
			Buttons.bl.show()
			set_wall(Cell.WALLS.DEC_DIAG)
		_:
			push_error("Not a valid type of cell:" + str(type))


func set_wall(wall : Cell.WALLS) -> void:
	match wall:
		Cell.WALLS.TOP:
			Walls.top.show()
		Cell.WALLS.RIGHT:
			Walls.right.show()
		Cell.WALLS.BOTTOM:
			Walls.bottom.show()
		Cell.WALLS.LEFT:
			Walls.left.show()
		Cell.WALLS.INC_DIAG:
			Walls.inc.show()
		Cell.WALLS.DEC_DIAG:
			Walls.dec.show()
		_:
			push_error("Not a valid wall:" + str(wall))


func remove_water():
	for water in Waters.values():
		water.hide()


func set_water(water : Cell.WATERS, value: bool) -> void:
	match water:
		Cell.WATERS.SINGLE:
			Waters.s.visible = value
		Cell.WATERS.TOPLEFT:
			Waters.tl.visible = value
		Cell.WATERS.TOPRIGHT:
			Waters.tr.visible = value
		Cell.WATERS.BOTTOMRIGHT:
			Waters.br.visible = value
		Cell.WATERS.BOTTOMLEFT:
			Waters.bl.visible = value
		Cell.WATERS.NONE:
			remove_water()
		_:
			push_error("Not a valid water:" + str(water))


func _on_button_pressed(which : String) -> void:
	emit_signal("pressed", row, column, which)
