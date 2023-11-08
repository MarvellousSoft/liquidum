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


func setup(type : E.CellType, i : int, j : int) -> void:
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
		E.CellType.Single:
			Buttons.s.show()
		E.CellType.IncDiag:
			Buttons.tl.show()
			Buttons.br.show()
			set_wall(E.Walls.IncDiag)
		E.CellType.DecDiag:
			Buttons.tr.show()
			Buttons.bl.show()
			set_wall(E.Walls.DecDiag)
		_:
			push_error("Not a valid type of cell:" + str(type))


func set_wall(wall : E.Walls) -> void:
	match wall:
		E.Walls.Top:
			Walls.top.show()
		E.Walls.Right:
			Walls.right.show()
		E.Walls.Bottom:
			Walls.bottom.show()
		E.Walls.Left:
			Walls.left.show()
		E.Walls.IncDiag:
			Walls.inc.show()
		E.Walls.DecDiag:
			Walls.dec.show()
		_:
			push_error("Not a valid wall:" + str(wall))


func remove_water():
	for water in Waters.values():
		water.hide()


func set_water(water : E.Waters, value: bool) -> void:
	match water:
		E.Waters.Single:
			Waters.s.visible = value
		E.Waters.TopLeft:
			Waters.tl.visible = value
		E.Waters.TopRight:
			Waters.tr.visible = value
		E.Waters.BottomRight:
			Waters.br.visible = value
		E.Waters.BottomLeft:
			Waters.bl.visible = value
		E.Waters.None:
			remove_water()
		_:
			push_error("Not a valid water:" + str(water))


func _on_button_pressed(which : String) -> void:
	emit_signal("pressed", row, column, which)
