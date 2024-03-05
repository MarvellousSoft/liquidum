class_name DevPanel
extends VBoxContainer


signal use_strategies()
signal full_solve()
signal generate()
signal load_grid(g: GridModel)
signal save()
signal copy_to_editor()


@onready var StrategyList: MenuButton = $StrategyList
@onready var ForcedStrategyList: MenuButton = $ForcedStrategyList
@onready var Guesses: SpinBox = $Guesses
@onready var FlavorOptions: OptionButton = $FlavorOptions
@onready var CancelSolve: Button = %CancelSolve
@onready var KeepWalls: Button = $KeepWalls
@onready var KeepWater: Button = $KeepWater
@onready var KeepVis: Button = $KeepVis


var l_gen := RandomLevelGenerator.new()
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
		popup.set_item_tooltip(i, SolverModel.STRATEGY_LIST[strategy].call(null).description())
		popup_forced.set_item_tooltip(i, SolverModel.STRATEGY_LIST[strategy].call(null).description())
		i += 1
	for flavor in RandomFlavors.Flavor:
		FlavorOptions.add_item(flavor)
	FlavorOptions.add_item("No flavor", 1000)
	FlavorOptions.selected = RandomFlavors.Flavor.size()


func _toggled_item(index: int, button: MenuButton) -> void:
	AudioManager.play_sfx("button_pressed")
	button.get_popup().toggle_item_checked(index)


func _gen_puzzle(cur_grid: GridModel, cur_hints: Level.HintVisibility) -> GridModel:
	var time := Time.get_unix_time_from_system()
	var strategies := selected_strategies()
	var forced_strategies := selected_forced_strategies()
	while true:
		if Time.get_unix_time_from_system() > time + 30:
			print("Took too long generating")
			$Seed.placeholder_text = "Gave up"
			return null
		assert(not $Interesting.button_pressed or forced_strategies.is_empty(), "Can't generate interesting and have forced strategy")
		var flavor = FlavorOptions.get_selected_id()
		assert(flavor == 1000 or forced_strategies.is_empty(), "Can't generate flavor and have forced strategy")
		var rng := RandomNumberGenerator.new()
		var rseed: String = str(randi() % 1000000)
		if $Seed.text != "":
			rseed = $Seed.text
		else:
			$Seed.placeholder_text = "Seed: %s" % rseed
		rng.seed = RandomHub.consistent_hash(rseed)
		if flavor < 1000:
			var g := await RandomFlavors.gen(l_gen, rng, flavor)
			if g != null:
				g.solution_c_left.clear()
				g.solution_c_right.clear()
				return g
		else:
			# TODO: This can be refactored to use RandomLevelGenerator
			var g: GridModel
			var gen := Generator.builder().with_diags($Diags.button_pressed).with_boats($Boats.button_pressed).build(rng.randi())
			if KeepWalls.button_pressed:
				g = GridImpl.import_data(cur_grid.export_data(), GridModel.LoadMode.Editor)
				if not KeepWater.button_pressed:
					g.clear_content()
					if $Boats.button_pressed:
						gen.randomize_boats(g)
					gen.randomize_water(g)
			else:
				g = gen.generate(cur_grid.rows(), cur_grid.cols())
			if KeepVis.button_pressed:
				cur_hints.apply_to_grid(g)
			else:
				Level.random_visibility(g, g.count_boats() > 0).apply_to_grid(g)
				if $Aquariums.button_pressed:
					Generator.randomize_aquarium_hints(rng, g, randf())
			if not forced_strategies.is_empty() or ($Interesting.button_pressed and $Seed.text == ""):
				var retry := true
				if forced_strategies.is_empty():
					var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
					g2.clear_content()
					retry = SolverModel.new().full_solve(g2, strategies, func(): return Time.get_unix_time_from_system() > time + 30, true, int(Guesses.value)) != SolverModel.SolveResult.SolvedUnique
				else:
					var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Solution)
					retry = not SolverModel.new().can_solve_with_strategies(g2, strategies, forced_strategies)
					if not retry:
						g2.clear_content()
						SolverModel.new().apply_strategies(g2, strategies)
						assert(g2.are_hints_satisfied())
						g = GridImpl.import_data(g2.export_data(), GridModel.LoadMode.Editor)
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
	for node in [$Generate, $Interesting, $Seed, $Diags, KeepWalls, KeepWater, KeepVis, $Paste, FlavorOptions]:
		node.visible = editor_mode
	if editor_mode:
		_on_keep_walls_toggled(KeepWalls.button_pressed)
		_on_keep_water_toggled(KeepWater.button_pressed)
		_on_keep_vis_toggled(KeepVis.button_pressed)


func gen_level(cur_grid: GridModel, cur_hints: Level.HintVisibility) -> GridModel:
	$Generate.disabled = true
	var g := await _gen_puzzle(cur_grid, cur_hints)
	if g != null:
		$FullSolveType.text = ""
	$Generate.disabled = false
	return g

func _solve(g: GridModel) -> SolverModel.SolveResult:
	return SolverModel.new().full_solve(g, selected_strategies(), func(): return CancelSolve.button_pressed, true, int(Guesses.value))

func _process(_dt: float) -> void:
	if solve_thread.is_started() and not solve_thread.is_alive():
		var r = solve_thread.wait_to_finish()
		set_solve_type(r)
		%FullSolve.disabled = false
		CancelSolve.visible = false

func start_solve(g: GridModel) -> void:
	assert(not solve_thread.is_started())
	%FullSolve.disabled = true
	CancelSolve.visible = true
	CancelSolve.button_pressed = false
	solve_thread.start(_solve.bind(g))

func _on_strategies_pressed():
	AudioManager.play_sfx("button_pressed")
	use_strategies.emit()


func _on_full_solve_pressed():
	$FullSolveType.text = ""
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


func _on_paste_pressed():
	var txt := DisplayServer.clipboard_get()
	var g: GridModel
	if txt.begins_with("{"):
		var data = JSON.parse_string(txt)
		# Pasting full level instead of just grid
		if data.has("grid_data"):
			data = data.grid_data
		g = GridImpl.import_data(data, GridModel.LoadMode.Testing)
	else:
		g = GridImpl.from_str(txt, GridModel.LoadMode.Testing)
	load_grid.emit(g)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_save_pressed():
	save.emit()

func should_reset_visible_aquariums() -> bool:
	return $Aquariums.button_pressed

func _on_copy_to_editor_pressed():
	AudioManager.play_sfx("button_pressed")
	copy_to_editor.emit()

func do_copy_to_editor(grid: GridModel, hints: Level.HintVisibility) -> void:
	var g: GridModel
	if not grid.editor_mode():
		g = GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Testing)
		# Copy solution, probably should be moved somewhere
		for i in g.rows():
			for j in g.cols():
				var c: GridImpl.PureCell = g._pure_cell(i, j)
				c.c_left = grid.solution_c_left[i][j]
				c.c_right = grid.solution_c_right[i][j]
	else:
		g = GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Testing)
		hints.apply_to_grid(g)
	assert(g.are_hints_satisfied())
	EditorHub.save_to_editor("Copied from DevPanel", g)


func _on_keep_walls_toggled(on: bool) -> void:
	$Diags.visible = not on
	KeepWater.visible = on

func _on_keep_water_toggled(on: bool) -> void:
	$Boats.visible = not on

func _on_keep_vis_toggled(on: bool) -> void:
	$Aquariums.visible = not on
	if on:
		$Aquariums.button_pressed = false
