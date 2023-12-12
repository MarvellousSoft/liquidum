class_name DevPanel
extends VBoxContainer


signal use_strategies()
signal full_solve()
signal generate()
signal randomize_water()
signal randomize_visibility()
signal load_grid(g: GridModel)
signal save()


@onready var StrategyList: MenuButton = $StrategyList
@onready var ForcedStrategyList: MenuButton = $ForcedStrategyList

var solve_thread: Thread = Thread.new()

func _ready() -> void:
	var popup := StrategyList.get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.index_pressed.connect(_toggled_item.bind(StrategyList))
	var popup_forced := ForcedStrategyList.get_popup()
	popup_forced.hide_on_checkable_item_selection = false
	popup_forced.index_pressed.connect(_toggled_item.bind(ForcedStrategyList))
	var i := 0
	for strategy in SolverModel.STRATEGY_LIST:
		popup_forced.add_check_item(strategy)
		popup.add_check_item(strategy)
		popup.set_item_checked(i, true)
		popup.set_item_tooltip(i, SolverModel.STRATEGY_LIST[strategy].description())
		popup_forced.set_item_tooltip(i, SolverModel.STRATEGY_LIST[strategy].description())
		i += 1


func _toggled_item(index: int, button: MenuButton) -> void:
	AudioManager.play_sfx("button_pressed")
	button.get_popup().toggle_item_checked(index)


func _gen_puzzle(rows: int, cols: int, hints: Level.HintVisibility) -> GridModel:
	var time := Time.get_unix_time_from_system()
	var strategies := selected_strategies()
	var forced_strategies := selected_forced_strategies()
	while true:
		if Time.get_unix_time_from_system() > time + 20:
			print("Took too long generating")
			$Seed.placeholder_text = "Gave up"
			return null
		assert(not $Interesting.button_pressed or forced_strategies.is_empty(), "Can't generate interesting and have forced strategy")
		var rseed := randi() % 100000
		if $Seed.text != "":
			rseed = int($Seed.text)
		else:
			$Seed.placeholder_text = "Seed: %d" % rseed
		var gen := Generator.new(rseed, $Diags.button_pressed)
		var g := gen.generate(rows, cols)
		if not forced_strategies.is_empty() or ($Interesting.button_pressed and $Seed.text == ""):
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
			g2.clear_content()
			hints.apply_to_grid(g2)
			var retry := true
			if forced_strategies.is_empty():
				retry = SolverModel.new().full_solve(g2, strategies) != SolverModel.SolveResult.SolvedUnique
			else:
				retry = not SolverModel.new().can_solve_with_strategies(g2, strategies, forced_strategies)
			if retry:
				await get_tree().process_frame
				continue
		return g
	assert(false, "Unreachable")
	return null


func set_solve_type(type: SolverModel.SolveResult) -> void:
	$FullSolveType.text = SolverModel.SolveResult.find_key(type)


func god_mode_enabled() -> bool:
	return $GodMode.is_pressed()

func _checked_items(popup: PopupMenu) -> Array:
	return range(popup.item_count).filter(func(i): return popup.is_item_checked(i)).map(func(i): return popup.get_item_text(i))
	

func selected_strategies() -> Array:
	return _checked_items(StrategyList.get_popup())

func selected_forced_strategies() -> Array:
	return _checked_items(ForcedStrategyList.get_popup())

func setup(editor_mode: bool) -> void:
	for node in [$Strategies, $GodMode]:
		node.visible = not editor_mode
	for node in [$Generate, $Interesting, $Seed, $Diags, $RandomizeWater, $RandomizeVisibility, $Paste]:
		node.visible = editor_mode


func gen_level(rows: int, cols: int, hints: Level.HintVisibility) -> GridModel:
	$Generate.disabled = true
	var g := await _gen_puzzle(rows, cols, hints)
	if g != null:
		$FullSolveType.text = ""
	$Generate.disabled = false
	return g

func _solve(g: GridModel) -> SolverModel.SolveResult:
	return SolverModel.new().full_solve(g, selected_strategies())

func _process(_dt: float) -> void:
	if solve_thread.is_started() and not solve_thread.is_alive():
		var r = solve_thread.wait_to_finish()
		set_solve_type(r)
		$FullSolve.disabled = false

func start_solve(g: GridModel) -> void:
	assert(not solve_thread.is_started())
	$FullSolve.disabled = true
	solve_thread.start(_solve.bind(g))

func _on_strategies_pressed():
	AudioManager.play_sfx("button_pressed")
	use_strategies.emit()


func _on_full_solve_pressed():
	AudioManager.play_sfx("button_pressed")
	if solve_thread.is_started():
		pass
	else:
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
	var txt := DisplayServer.clipboard_get()
	var g: GridModel
	if txt.begins_with("{"):
		g = GridImpl.import_data(JSON.parse_string(txt), GridModel.LoadMode.Testing)
	else:
		g = GridImpl.from_str(txt, GridModel.LoadMode.Testing)
	load_grid.emit(g)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_randomize_visibility_pressed():
	AudioManager.play_sfx("button_pressed")
	randomize_visibility.emit()


func _on_save_pressed():
	save.emit()
