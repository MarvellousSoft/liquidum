extends Node2D

const GRID = preload("res://game/level/Grid.tscn")

@onready var GridNode = $CenterContainer/Grid

func _ready():
	setup("""
......
|....╲
......
|╲./|.
......
L../.╲
......
L._╲_.""")


func setup(level : String):
	GridNode.setup(level)
