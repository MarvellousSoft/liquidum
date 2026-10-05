class_name TestRunner
extends Control

const DESIRED_W := 780.0

static var running: bool = false

@onready var g1: GridView = $Grid1
@onready var g2: GridView = $Grid2

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.


const PANDORA_OPTION_OFFSET := 100

var _infinite_gen_running := false
var _active_test_tasks: Dictionary = {}

func _init() -> void:
	TestRunner.running = true

func _exit_tree() -> void:
	_infinite_gen_running = false
	for task_id in _active_test_tasks.keys():
		var data: Dictionary = _active_test_tasks[task_id]
		if data.has("gen_instance") and data["gen_instance"] != null:
			data["gen_instance"].cancel()
		WorkerThreadPool.wait_for_task_completion(task_id)
	_active_test_tasks.clear()

func _ready() -> void:
	$BrushPicker.setup(true, true)
	for section in range(1, ExtraLevelLister.count_all_game_sections(true) + 1):
		if ExtraLevelLister.section_endless_flavor(section) != -1:
			%EndlessOptions.add_item(ExtraLevelLister.section_name(section), section)
	for mode in PandoraHub.Mode.values():
		var mode_name: String = PandoraHub.Mode.find_key(mode)
		%EndlessOptions.add_item("Pandora's Box - %s" % mode_name, PANDORA_OPTION_OFFSET + mode)

func _on_run_pressed():
	$Tests.run_all_tests()

func _on_tests_show_grids(s1: String, s2: String):
	g1.setup(GridImpl.from_str(s1, GridModel.LoadMode.Testing))
	g2.setup(GridImpl.from_str(s2, GridModel.LoadMode.Testing))
	scale_grids()


func scale_grids() -> void:
	await get_tree().process_frame
	var s := DESIRED_W / g2.get_grid_size().x
	g1.scale = Vector2(s, s)
	g2.scale = Vector2(s, s)

func all_strategies() -> Array:
	return SolverModel.STRATEGY_LIST.keys()


func _on_auto_solve_pressed():
	g2.apply_strategies(all_strategies())


func _on_grid_2_updated():
	if %GodMode.button_pressed:
		g2.apply_strategies(all_strategies(), false, false)


func _on_paste_pressed():
	g2.setup(GridImpl.from_str(DisplayServer.clipboard_get(), GridModel.LoadMode.Solution))
	scale_grids()


func _on_full_solve_pressed():
	var r := g2.full_solve(all_strategies())
	var solve_type: String = SolverModel.SolveResult.find_key(r)
	print("Level is %s" % solve_type)
	%SolvedType.text = solve_type

const PLAYED_STATS := ["daily2", "editor", "playtest", "random"]
const INT_STATS := ["daily_all_levels", "random_all_levels", "random_insane_levels", "random_insane_good_levels"]

func _on_print_global_stats_pressed() -> void:
	if not SteamManager.enabled:
		return
	SteamManager.steam.requestGlobalStats(5)
	await SteamManager.steam.global_stats_received
	for stat in PLAYED_STATS:
		var val = SteamManager.steam.getGlobalStatFloat(stat + "_secs")
		var tot = SteamManager.steam.getGlobalStatInt(stat + "_total")
		print("%s = %s tot %s avg" % [stat, Level.time_str(int(val)), Level.time_str(int(val / tot))])
	for stat in INT_STATS:
		var val = SteamManager.steam.getGlobalStatInt(stat)
		print("%s = %d" % [stat, val])


func _on_print_local_stats_pressed():
	if not SteamManager.enabled:
		return
	for stat in PLAYED_STATS:
		var val = SteamManager.steam.getStatFloat(stat + "_secs")
		var tot = SteamManager.steam.getStatInt(stat + "_total")
		print("%s = %.0f (total %d)" % [stat, val, tot])
	for int_stat in INT_STATS:
		print("%s = %d" % [int_stat, SteamManager.steam.getStatInt(int_stat)])


func _on_preprocess_dailies_pressed(year: int = -1) -> void:
	if year == -1:
		year = int(%DailiesYear.value)
	print("Generating Dailies for %d" % [year])
	%DailiesYear.value = year
	var prep := FileManager.load_dailies(year)
	var unixtime := Time.get_unix_time_from_datetime_string("%s-01-01" % year)
	var gen := RandomLevelGenerator.new()
	%DailiesProgress.value = 0
	%DailiesProgress.visible = true
	%DailiesYear.visible = false
	%DailiesButton.visible = false
	%DailiesCancel.visible = true
	%DailiesCancel.button_pressed = false
	var watch := Stopwatch.new()
	var today := Time.get_datetime_string_from_system(true)
	today = today.substr(0, today.find("T"))
	while true:
		var date := Time.get_datetime_string_from_unix_time(unixtime)
		date = date.substr(0, date.find("T"))
		if date >= today:
			if not date.begins_with(str(year)) or %DailiesCancel.button_pressed:
				break
			var dict := Time.get_datetime_dict_from_datetime_string(date, false)
			if prep.success_state(dict) == 0:
				await DailyButton.gen_level(gen, date)
				prep.set_success_state(dict, gen.success_state)
			elif %PrepCheck.button_pressed:
				# Check it is correct
				await DailyButton.gen_level(gen, date)
			if watch.elapsed() > 60.:
				watch.elapsed_reset()
				FileManager.save_dailies(year, prep)
		%DailiesProgress.value += 1
		unixtime += 24 * 60 * 60
	FileManager.save_dailies(year, prep)
	if not %DailiesCancel.button_pressed:
		_on_preprocess_dailies_pressed(year + 1)
	else:
		%DailiesProgress.visible = false
		%DailiesYear.visible = true
		%DailiesButton.visible = true
		%DailiesCancel.visible = false


func _on_dif_button_pressed():
	var dif: RandomHub.Difficulty = %DifOptions.get_selected_id()
	var prep := FileManager.load_preprocessed_difficulty(dif)
	var gen := RandomLevelGenerator.new()
	%DifProgress.value = 0
	%DifProgress.visible = true
	%DifOptions.disabled = true
	%DifButton.visible = false
	%DifCancel.visible = true
	%DifCancel.button_pressed = false
	var watch := Stopwatch.new()
	var rng := RandomNumberGenerator.new()
	for i in 1000:
		if %DifCancel.button_pressed:
			break
		rng.seed = RandomHub.consistent_hash(str(i))
		if prep.success_state(i) == 0:
			await RandomHub.gen_from_difficulty(gen, rng, dif)
			prep.set_success_state(i, gen.success_state)
		elif %PrepCheck.button_pressed:
			# Check it is correct
			rng.state = prep.success_state(i)
			await RandomHub.gen_from_difficulty(gen, rng, dif)
			assert(gen.success_state == prep.success_state(i))
		if watch.elapsed() > 60.:
			watch.elapsed_reset()
			FileManager.save_preprocessed_difficulty(prep)
		%DifProgress.value += 1
	%DifCancel.visible = false
	%DifProgress.visible = false
	%DifButton.visible = true
	%DifOptions.disabled = false
	FileManager.save_preprocessed_difficulty(prep)

func _gen_endless(i: int, cancel_but: Button, prep_check: bool, rets: Array[Dictionary], mode: int, endless_flavor: RandomFlavors.Flavor, prep_pandora: PreprocessedPandora, prep_endless: PreprocessedEndless) -> void:
	if cancel_but.button_pressed:
		rets[i] = {status = "cancelled"}
		return
	var gen := RandomLevelGenerator.new()
	gen.direct_thread = true
	var is_pandora := mode != -1
	var seed_str := str(i)
	var flavor: RandomFlavors.Flavor
	if is_pandora:
		if mode == PandoraHub.Mode.Pandora:
			var flavor_rng := RandomNumberGenerator.new()
			flavor_rng.seed = RandomHub.consistent_hash(seed_str + "-flavor")
			flavor = PandoraHub.PANDORA_FLAVORS[flavor_rng.randi() % PandoraHub.PANDORA_FLAVORS.size()]
		else:
			flavor = PandoraHub.PANDORA_FLAVORS[mode]
	else:
		flavor = endless_flavor
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash(seed_str)
	var current_state := prep_pandora.success_state(i) if is_pandora else prep_endless.success_state(i)
	if current_state == 0:
		print("Starting endless level %d" % [i])
		await RandomFlavors.gen(gen, rng, flavor)
		rets[i] = {status = "successfully generated"}
		if is_pandora:
			prep_pandora.set_success_state(i, gen.success_state)
		else:
			prep_endless.set_success_state(i, gen.success_state)
	elif prep_check:
		# Check it is correct
		rng.state = current_state
		await RandomFlavors.gen(gen, rng, flavor)
		rets[i] = {status = "verified if it was ok", result = (gen.success_state == current_state)}
		assert(gen.success_state == current_state)
	else:
		rets[i] = {status = "was already generated"}

func _on_endless_button_pressed() -> void:
	var selected_id: int = %EndlessOptions.get_selected_id()
	var is_pandora := selected_id >= PANDORA_OPTION_OFFSET
	var mode := selected_id - PANDORA_OPTION_OFFSET if is_pandora else -1
	var section := selected_id if not is_pandora else -1

	var prep_pandora: PreprocessedPandora = null
	var prep_endless: PreprocessedEndless = null
	var endless_flavor: RandomFlavors.Flavor
	var count: int = 1000

	if is_pandora:
		prep_pandora = FileManager.load_preprocessed_pandora(mode)
		prep_pandora._success_states.resize(count)
	else:
		prep_endless = FileManager.load_preprocessed_endless(section)
		prep_endless._success_states.resize(count)
		endless_flavor = ExtraLevelLister.section_endless_flavor(section) as RandomFlavors.Flavor


	%EndlessProgress.value = 0
	%EndlessProgress.max_value = count
	%EndlessProgress.visible = true
	%EndlessOptions.disabled = true
	%EndlessButton.visible = false
	%EndlessCancel.visible = true
	%EndlessCancel.button_pressed = false
	var rets : Array[Dictionary] = []
	rets.resize(count)
	# For easier debugging
	# Snakes are bugged for some reason
	var FORCE_SEQUENTIAL := (mode == PandoraHub.Mode.Snake or mode == PandoraHub.Mode.Pandora) or true
	
	var group_id := WorkerThreadPool.add_group_task(self._gen_endless.bind(%EndlessCancel, %PrepCheck.button_pressed, rets, mode, endless_flavor, prep_pandora, prep_endless), count, 1 if FORCE_SEQUENTIAL else -1)
	var watch := Stopwatch.new()

	while WorkerThreadPool.get_group_processed_element_count(group_id) < count:
		if %EndlessCancel.button_pressed:
			break
		if watch.elapsed() > 30.:
			watch.elapsed_reset()
			if is_pandora:
				FileManager.save_preprocessed_pandora(prep_pandora)
			else:
				FileManager.save_preprocessed_endless(section, prep_endless)
		var ct := WorkerThreadPool.get_group_processed_element_count(group_id)
		if ct > %EndlessProgress.value:
			print("Finished %d endless levels" % [ct])
			%EndlessProgress.value = ct
		await get_tree().create_timer(0.5).timeout
	while not WorkerThreadPool.is_group_task_completed(group_id):
		await get_tree().create_timer(0.5).timeout
	var by_status: Dictionary = {}
	for ret in rets:
		if not by_status.has(ret.status):
			by_status[ret.status] = 0
		by_status[ret.status] += 1
	print(by_status)
	if is_pandora:
		FileManager.save_preprocessed_pandora(prep_pandora)
		if not %EndlessCancel.button_pressed and mode < PandoraHub.Mode.Pandora:
			%EndlessOptions.select(%EndlessOptions.get_item_index(selected_id) + 1)
			await _on_endless_button_pressed()
			return
	else:
		FileManager.save_preprocessed_endless(section, prep_endless)
	%EndlessCancel.visible = false
	%EndlessProgress.visible = false
	%EndlessButton.visible = true
	%EndlessOptions.disabled = false

func _on_reset_stats_pressed():
	SteamManager.steam.resetAllStats(true)
	#SteamManager.steam.requestCurrentStats()


func _on_preprocess_weeklies_pressed() -> void:
	var year := int(%WeekliesYear.value)
	print("====== PREPROCESSING WEEKLIES FOR %d ======" % [year])
	var prep := FileManager.load_preprocessed_weeklies(year)
	var first_monday: String = PreprocessedWeeklies.first_monday_of_the_year(year)
	var unixtime := Time.get_unix_time_from_datetime_string(first_monday)
	var gen := RandomLevelGenerator.new()
	%WeekliesProgress.value = 0
	%WeekliesProgress.visible = true
	%WeekliesButton.visible = false
	%WeekliesYear.visible = false
	%WeekliesCancel.visible = true
	%WeekliesCancel.button_pressed = false
	var watch := Stopwatch.new()
	var cur_period := WeeklyButton.get_curr_fst_day()
	while true:
		var monday := WeeklyButton._day_strip_time(unixtime)
		if not monday.begins_with(str(year)) or %WeekliesCancel.button_pressed:
			break
		if monday >= cur_period:
			for i in 10:
				if %WeekliesCancel.button_pressed:
					break
				if prep.success_state(monday, i) == 0:
					await WeeklyButton.gen_level(gen, monday, i + 1, 10)
					prep.set_success_state(monday, i, gen.success_state)
				elif %PrepCheck.button_pressed:
					# Check it is correct
					await WeeklyButton.gen_level(gen, monday, i + 1, 10)
				if watch.elapsed() > 30.:
					watch.elapsed_reset()
					FileManager.save_preprocessed_weeklies(year, prep)
		%WeekliesProgress.value += 1
		unixtime += 7 * 24 * 60 * 60
	FileManager.save_preprocessed_weeklies(year, prep)
	if not %WeekliesCancel.button_pressed:
		%WeekliesYear.value = year + 1
		await _on_preprocess_weeklies_pressed()
		return
	%WeekliesProgress.visible = false
	%WeekliesYear.visible = true
	%WeekliesButton.visible = true
	%WeekliesCancel.visible = false

func _on_infinite_gen_button_pressed() -> void:
	if _infinite_gen_running:
		return
	run_infinite_generator_test()

func _on_infinite_gen_cancel_pressed() -> void:
	if _infinite_gen_running:
		_infinite_gen_running = false
		%InfiniteGenStatus.text = "Cancelling..."
		for data in _active_test_tasks.values():
			if data.has("gen_instance") and data["gen_instance"] != null:
				data["gen_instance"].cancel()

func _execute_test_item(item: Dictionary, cycle: int, seed_val: int, gen: RandomLevelGenerator) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var start_time := Time.get_ticks_usec()
	var item_name: String = item["name"]

	var grid: GridModel = null
	if item["type"] == "difficulty":
		grid = await RandomHub.gen_from_difficulty(gen, rng, item["id"])
	else:
		grid = await RandomFlavors.gen(gen, rng, item["id"])

	if not _infinite_gen_running:
		return {}

	# 1. Generator crash / failure / null check
	if grid == null:
		if gen.tries >= gen.MAX_TRIES:
			return {"status": "too_many_tries", "item_name": item_name, "cycle": cycle, "seed": seed_val, "tries": gen.tries, "grid": null}
		return {"status": "error", "error": "Generator failed or returned null", "item_name": item_name, "cycle": cycle, "seed": seed_val, "grid": null}

	# 2. Check if generator encountered Unsolvable during candidate generation
	if gen.had_unsolvable_error:
		return {"status": "error", "error": "Generator encountered Unsolvable state during candidate generation", "item_name": item_name, "cycle": cycle, "seed": seed_val, "grid": grid}

	# 3. Check if hints are satisfied with generated solution
	if not grid.are_hints_satisfied():
		return {"status": "error", "error": "Generated grid solution does not satisfy hints", "item_name": item_name, "cycle": cycle, "seed": seed_val, "grid": grid}

	# 4. Run solver on generated level (testing grid)
	var test_g := GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Testing)
	test_g.clear_content()
	var solver := SolverModel.new()
	var solve_result := solver.full_solve(test_g, SolverModel.STRATEGY_LIST.keys(), func(): return not _infinite_gen_running)

	if not _infinite_gen_running:
		return {}

	if solve_result == SolverModel.SolveResult.Unsolvable:
		return {"status": "error", "error": "Solver returned Unsolvable for generated level", "item_name": item_name, "cycle": cycle, "seed": seed_val, "grid": grid}

	var elapsed_s := (Time.get_ticks_usec() - start_time) / 1000000.0
	var solve_name: String = SolverModel.SolveResult.find_key(solve_result)
	return {"status": "ok", "solve_name": solve_name, "elapsed_s": elapsed_s, "item_name": item_name, "cycle": cycle, "seed": seed_val, "grid": grid}

func run_infinite_generator_test() -> void:
	_infinite_gen_running = true
	%InfiniteGenButton.visible = false
	%InfiniteGenCancel.visible = true
	%InfiniteGenCancel.button_pressed = false
	%InfiniteGenStatus.text = "Starting infinite generator test with WorkerThreadPool..."
	print("--- Starting Infinite Generator Test (WorkerThreadPool) ---")

	# Build ordered test list: all difficulties in order, then all flavors in order
	var test_items: Array[Dictionary] = []
	for dif in RandomHub.Difficulty.values():
		test_items.append({
			"type": "difficulty",
			"id": dif,
			"name": "Difficulty.%s" % RandomHub.Difficulty.find_key(dif),
		})
	for flavor in RandomFlavors.Flavor.values():
		test_items.append({
			"type": "flavor",
			"id": flavor,
			"name": "Flavor.%s" % RandomFlavors.Flavor.find_key(flavor),
		})

	var num_workers := maxi(2, OS.get_processor_count() - 1)
	print("Running infinite tests with %d worker threads in WorkerThreadPool" % num_workers)

	var cycle := 1
	var item_index := 0
	var total_tested := 0
	_active_test_tasks.clear()

	while _infinite_gen_running and not %InfiniteGenCancel.button_pressed:
		# Queue tasks up to num_workers
		while _active_test_tasks.size() < num_workers and _infinite_gen_running and not %InfiniteGenCancel.button_pressed:
			var item: Dictionary = test_items[item_index]
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var current_seed := rng.seed
			var gen := RandomLevelGenerator.new()
			gen.direct_thread = true

			var task_data := {
				"item": item,
				"cycle": cycle,
				"seed": current_seed,
				"gen_instance": gen,
				"result": {},
			}

			var task_id := WorkerThreadPool.add_task(func():
				task_data["result"] = await _execute_test_item(task_data["item"], task_data["cycle"], task_data["seed"], task_data["gen_instance"])
			)
			_active_test_tasks[task_id] = task_data

			item_index += 1
			if item_index >= test_items.size():
				item_index = 0
				cycle += 1

		# Yield to let main thread handle UI and frame updates
		await get_tree().process_frame

		# Process finished tasks
		var finished_ids: Array = []
		for task_id in _active_test_tasks.keys():
			if WorkerThreadPool.is_task_completed(task_id):
				finished_ids.append(task_id)

		for task_id in finished_ids:
			WorkerThreadPool.wait_for_task_completion(task_id)
			var data: Dictionary = _active_test_tasks[task_id]
			_active_test_tasks.erase(task_id)

			var res: Dictionary = data["result"]
			if res.is_empty():
				continue

			if res["status"] == "too_many_tries":
				print("[Cycle %d] %s too many tries (%d), which is bad but not a fail." % [res["cycle"], res["item_name"], res["tries"]])
			elif res["status"] == "error":
				_infinite_gen_fail("[Cycle %d] %s for %s (seed: %d)" % [res["cycle"], res["error"], res["item_name"], res["seed"]], res["grid"])
				for remaining_id in _active_test_tasks.keys():
					_active_test_tasks[remaining_id]["gen_instance"].cancel()
					WorkerThreadPool.wait_for_task_completion(remaining_id)
				_active_test_tasks.clear()
				return
			elif res["status"] == "ok":
				total_tested += 1
				%InfiniteGenStatus.text = "[Cycle %d | #%d] %s OK" % [res["cycle"], total_tested, res["item_name"]]
				print("[Cycle %d | #%d] %s OK (%s in %.1fs)" % [res["cycle"], total_tested, res["item_name"], res["solve_name"], res["elapsed_s"]])

	# Clean up on cancellation
	_infinite_gen_running = false
	for remaining_id in _active_test_tasks.keys():
		_active_test_tasks[remaining_id]["gen_instance"].cancel()
		WorkerThreadPool.wait_for_task_completion(remaining_id)
	_active_test_tasks.clear()

	%InfiniteGenCancel.visible = false
	%InfiniteGenButton.visible = true
	%InfiniteGenStatus.text = "Stopped. Successfully verified %d levels without errors." % total_tested
	print("--- Infinite Generator Test Stopped (%d levels verified) ---" % total_tested)

func _infinite_gen_fail(msg: String, grid: GridModel = null) -> void:
	_infinite_gen_running = false
	for data in _active_test_tasks.values():
		if data.has("gen_instance") and data["gen_instance"] != null:
			data["gen_instance"].cancel()
	push_error("INFINITE GEN TEST FAILED: " + msg)
	print("==================================================")
	print("INFINITE GEN TEST FAILED: ", msg)
	if grid != null:
		print("Grid content:")
		print(grid.to_str())
		print("Grid export:")
		print(JSON.stringify(grid.export_data()))
		g1.setup(GridImpl.import_data(grid.export_data(), GridModel.LoadMode.SolutionNoClear))
		g2.setup(GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Testing))
		scale_grids()
	print("==================================================")
	%InfiniteGenStatus.text = "FAILED: " + msg
	%InfiniteGenCancel.visible = false
	%InfiniteGenButton.visible = true
	assert(false, "Infinite Gen Test failed: " + msg)
