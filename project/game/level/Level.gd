extends Node2D

const GRID = preload("res://game/level/Grid.tscn")

@onready var GridNode = $CenterContainer/Grid

func _ready():
	setup(10,10)


func setup(n : int, m : int):
	GridNode.setup(n, m)
