extends Cell

const DIAGONAL_MASK = preload("res://assets/images/ui/diagonal_button_mask.png")

signal pressed

@onready var Buttons = {
	"s" : $Buttons/Single,
	"tl" : $Buttons/TopLeft,
	"tr" : $Buttons/TopRight,
	"bl" : $Buttons/BottomLeft,
	"br" : $Buttons/BottomRight,
}


var row : int
var column : int


func _ready():
	setup_click_masks()
	setup(Cell.TYPES.INC_DIAG, 1, 1)


func setup(type : Cell.TYPES, i : int, j : int) -> void:
	row = i
	column = j
	for buttons in Buttons.values():
		buttons.hide()
	match type:
		Cell.TYPES.SINGLE:
			Buttons.s.show()
		Cell.TYPES.INC_DIAG:
			Buttons.tl.show()
			Buttons.br.show()
		Cell.TYPES.DEC_DIAG:
			Buttons.tr.show()
			Buttons.bl.show()
		_:
			push_error("Not a valid type of cell:" + str(type))


func setup_click_masks() -> void:
	var bitmap = load("res://assets/images/ui/diagonal_button_mask.png")
	for button in [Buttons.tl, Buttons.tr, Buttons.br, Buttons.bl]:
		button.texture_click_mask = bitmap


func _on_button_pressed(which : String) -> void:
	emit_signal("pressed", which)
