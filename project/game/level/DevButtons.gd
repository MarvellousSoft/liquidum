extends VBoxContainer

signal use_strategies()
signal full_solve()
signal generate()

func set_solve_type(type: SolverModel.SolveResult) -> void:
	$FullSolveType.text = SolverModel.SolveResult.find_key(type)

func god_mode_enabled() -> bool:
	return $GodMode.is_pressed()

func setup(editor_mode: bool) -> void:
	for node in [$Strategies, $FullSolve, $FullSolveType, $GodMode]:
		node.visible = not editor_mode
	for node in [$Generate, $Interesting, $Seed, $Diags]:
		node.visible = editor_mode


func _gen_puzzle(rows: int, cols: int) -> GridModel:
	var time := Time.get_unix_time_from_system()
	while true:
		if Time.get_unix_time_from_system() > time + 10:
			print("Took too long generating")
			return null
		var rseed := randi() % 100000
		if $Seed.text != "":
			rseed = int($Seed.text)
		else:
			$Seed.placeholder_text = "Seed: %d" % rseed
		var gen := Generator.new(rseed)
		var g := gen.generate(rows, cols, $Diags.button_pressed)
		if $Interesting.button_pressed and $Seed.text == "":
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
			g2.clear_content()
			var r := SolverModel.new().full_solve(g2)
			if r != SolverModel.SolveResult.SolvedUnique:
				print("Generated %s. Trying again." % SolverModel.SolveResult.find_key(r))
				await get_tree().process_frame
				continue
		return g
	assert(false, "Unreachable")
	return null

func gen_level(rows: int, cols: int) -> GridModel:
	$Generate.disabled = true
	var g := await _gen_puzzle(rows, cols)
	$FullSolveType.text = ""
	$Generate.disabled = false
	return g

func _enter_tree():
	visible = Global.is_dev_mode()


func _on_strategies_pressed():
	use_strategies.emit()


func _on_full_solve_pressed():
	full_solve.emit()


func _on_generate_pressed():
	generate.emit()


func _on_god_mode_pressed():
	use_strategies.emit()
