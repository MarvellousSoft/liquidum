extends Node2D

const GRID = preload("res://game/level/Grid.tscn")

@onready var GridNode = $CenterContainer/Grid

func _ready():
	setup("""
.5.3.2.
1......
.|....╲
2......
.|╲./|.
4......
.L../.╲
3......
.L._╲_.""")


func setup(level : String):
	GridNode.setup(level)
