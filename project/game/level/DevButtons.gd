extends VBoxContainer

signal use_strategies()
signal full_solve()
signal generate(interesting: bool)

func set_solve_type(type: SolverModel.SolveResult) -> void:
	$FullSolveType.text = SolverModel.SolveResult.find_key(type)

func god_mode_enabled() -> bool:
	return $GodMode.is_pressed()


func _enter_tree():
	visible = Global.is_dev_mode()


func _on_strategies_pressed():
	use_strategies.emit()


func _on_full_solve_pressed():
	full_solve.emit()


func _on_generate_pressed():
	generate.emit($Interesting.is_pressed())
