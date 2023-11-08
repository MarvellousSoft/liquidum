extends Control

@onready var Number = $Number

func set_value(value : float):
	Number.text = str(value)

func no_hint():
	Number.text = ""
