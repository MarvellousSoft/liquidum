extends Node2D

const GRID = preload("res://game/level/Grid.tscn")

@onready var GridNode = $CenterContainer/Grid

func _ready():
	setup("""
h6.4.2.
1......
.|....╲
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
