extends Cell

const DIAGONAL_BUTTON_MASK = preload("res://assets/images/ui/diagonal_button_mask.png")

signal pressed

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
			Hints.inc.show()
		Cell.TYPES.DEC_DIAG:
			Buttons.tr.show()
			Buttons.bl.show()
			Hints.dec.show()
		_:
			push_error("Not a valid type of cell:" + str(type))


func _on_button_pressed(which : String) -> void:
	emit_signal("pressed", row, column, which)
