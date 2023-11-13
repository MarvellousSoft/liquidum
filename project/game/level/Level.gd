extends Node2D

@onready var GridNode : GridView = $CenterContainer/GridView

func _ready():
	setup("""
h6.4.2.
1##....
.L.|..╲
4......
.|╲./|.
4......
.L../.╲
3......
.L._╲|.""")


func setup(level : String):
	GridNode.setup(level)


func _on_solve_button_pressed():
	GridNode.auto_solve()


func _on_brush_picker_brushed_picked(mode : E.BrushMode):
	GridNode.set_brush_mode(mode)
