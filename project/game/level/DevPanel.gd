class_name DevPanel
extends VBoxContainer


signal use_strategies()
signal full_solve()
signal generate()
signal randomize_water()
signal load_grid(g: GridModel)


@onready var StrategyList: MenuButton = $StrategyList


func _ready() -> void:
	var popup := StrategyList.get_popup()
	popup.index_pressed.connect(_toggled_strategy)
	var i := 0
	for strategy in SolverModel.STRATEGY_LIST:
		popup.add_check_item(strategy)
		popup.set_item_checked(i, true)
		popup.set_item_tooltip(i, SolverModel.STRATEGY_LIST[strategy].description())
		i += 1


func _toggled_strategy(index: int) -> void:
	AudioManager.play_sfx("button_pressed")
	StrategyList.get_popup().toggle_item_checked(index)


func _enter_tree() -> void:
	visible = Global.is_dev_mode() or self == get_tree().current_scene


func _gen_puzzle(rows: int, cols: int, hints: Level.HintVisibility) -> GridModel:
	var time := Time.get_unix_time_from_system()
	var strategies := selected_strategies()
	while true:
		if Time.get_unix_time_from_system() > time + 10:
			print("Took too long generating")
			$Seed.placeholder_text = "Gave up"
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
			hints.apply_to_grid(g2)
			var r := SolverModel.new().full_solve(g2, strategies)
			if r != SolverModel.SolveResult.SolvedUnique:
				await get_tree().process_frame
				continue
		return g
	assert(false, "Unreachable")
	return null


func set_solve_type(type: SolverModel.SolveResult) -> void:
	$FullSolveType.text = SolverModel.SolveResult.find_key(type)


func god_mode_enabled() -> bool:
	return $GodMode.is_pressed()


func selected_strategies() -> Array:
	var popup := StrategyList.get_popup()
	return range(popup.item_count).filter(func(i): return popup.is_item_checked(i)).map(func(i): return popup.get_item_text(i))


func setup(editor_mode: bool) -> void:
	for node in [$Strategies, $GodMode]:
		node.visible = not editor_mode
	for node in [$Generate, $Interesting, $Seed, $Diags, $RandomizeWater, $Paste]:
		node.visible = editor_mode


func gen_level(rows: int, cols: int, hints: Level.HintVisibility) -> GridModel:
	$Generate.disabled = true
	var g := await _gen_puzzle(rows, cols, hints)
	if g != null:
		$FullSolveType.text = ""
	$Generate.disabled = false
	return g


func _on_strategies_pressed():
	AudioManager.play_sfx("button_pressed")
	use_strategies.emit()


func _on_full_solve_pressed():
	AudioManager.play_sfx("button_pressed")
	full_solve.emit()


func _on_generate_pressed():
	AudioManager.play_sfx("button_pressed")
	generate.emit()


func _on_god_mode_pressed():
	AudioManager.play_sfx("button_pressed")
	use_strategies.emit()


func _on_randomize_water_pressed():
	AudioManager.play_sfx("button_pressed")
	randomize_water.emit()


func _on_paste_pressed():
	var g := GridImpl.from_str(DisplayServer.clipboard_get(), GridModel.LoadMode.Editor)
	load_grid.emit(g)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
