class_name LevelLister
extends Node

func level_name(_section: int, _level: int) -> String:
	return GridModel.must_be_implemented()

func has_section(_section: int) -> int:
	return GridModel.must_be_implemented()

func count_all_game_sections() -> int:
	return GridModel.must_be_implemented()

func get_max_unlocked_level(_section: int) -> int:
	return GridModel.must_be_implemented()

func count_section_levels(_section: int) -> int:
	return GridModel.must_be_implemented()

func get_max_unlocked_levels(_section: int) -> int:
	return GridModel.must_be_implemented()

func count_completed_section_levels(_section: int) -> int:
	return GridModel.must_be_implemented()
