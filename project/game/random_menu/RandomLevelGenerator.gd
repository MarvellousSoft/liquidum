class_name RandomLevelGenerator

const MAX_TIME_PER_SOLVE = 30.0
const US_TO_S := 1000000.0

var gen_thread := Thread.new()
var cancel_gen := false
# State of the RNG right before generating a successful level
# Can be used to generate it very quickly
var success_state: int
var had_unsolvable_error := false
const MAX_TRIES := 2000
var tries := 0

func _init() -> void:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		GeneratingLevel.cancel.connect(self.cancel)

func _inner_gen_level(rng: RandomNumberGenerator, gen_size: Callable, apply_hints: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array, force_boats: bool) -> GridModel:
	var initial_seed := rng.seed
	var initial_state := rng.state
	var g: GridModel = null
	var solver := SolverModel.new()
	var found := false
	var start_time := Time.get_ticks_usec()
	var total_gen := 0
	var total_solve := 0
	var multiple_solutions := 0
	var too_easy := 0
	var too_hard := 0
	var inner_tries := 0
	for i in MAX_TRIES:
		tries += 1
		if ((i+1) % 25) == 0:
			print("Try %d: [too easy %d] [too hard %d] [multiple solutions %d]" % [i+1, too_easy, too_hard, multiple_solutions])
		if cancel_gen:
			break
		success_state = rng.state
		var start_gen := Time.get_ticks_usec()
		var sz: Vector2i = gen_size.call(rng)
		g = gen_options_builder.call(rng).build(rng.randi()).generate(sz.x, sz.y)
		total_gen += Time.get_ticks_usec() - start_gen
		if force_boats and g.count_boats() == 0:
			continue
		g.set_auto_update_hints(false)
		apply_hints.call(rng, g)

		var st := g.all_hints_status()
		if st != E.HintStatus.Satisfied:
			print("[%d] Weird, generated level is not satisfied, but %s on thread %d" % [OS.get_thread_caller_id(), E.HintStatus.find_key(st)])
			print("all_boats_hint_status: ", E.HintStatus.find_key(g.all_boats_hint_status()))
			print("all_waters_hint_status: ", E.HintStatus.find_key(g.all_waters_hint_status()))
			print("aquarium_hints_status: ", E.HintStatus.find_key(g.aquarium_hints_status()))
			for ri in g.rows():
				var rst := g.get_row_hint_status(ri, E.HintContent.Water)
				if rst != E.HintStatus.Satisfied:
					print("row %d water: %s (count: %f, hint: %f, type: %s)" % [ri, E.HintStatus.find_key(rst), g.count_water_row(ri), g.row_hints()[ri].water_count, E.HintType.find_key(g.row_hints()[ri].water_count_type)])
			for cj in g.cols():
				var cst := g.get_col_hint_status(cj, E.HintContent.Water)
				if cst != E.HintStatus.Satisfied:
					print("col %d water: %s (count: %f, hint: %f, type: %s)" % [cj, E.HintStatus.find_key(cst), g.count_water_col(cj), g.col_hints()[cj].water_count, E.HintType.find_key(g.col_hints()[cj].water_count_type)])
			for vi in g.rule_variants_status():
				print("variant status: ", E.HintStatus.find_key(vi))
			var st2 := g.all_hints_status()
			print("[%d] %s" % [OS.get_thread_caller_id(), E.HintStatus.find_key(st2)])
			if st2 == E.HintStatus.Satisfied:
				print("Waht the actual fuck")
			else:
				print(JSON.stringify(g.export_data()))
				assert(false)
		var start_solve := Time.get_ticks_usec()
		inner_tries += 1
		if not forced_strategies.is_empty():
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Solution)
			if solver.can_solve_with_strategies(g2, strategies, forced_strategies):
				total_solve += Time.get_ticks_usec() - start_solve
				g2.force_editor_mode()
				g2.clear_content()
				solver.apply_strategies(g2, strategies + forced_strategies)
				assert(g2.are_hints_satisfied())
				g2.force_editor_mode(false)
				g = g2
				found = true
				break
		else:
			var g_old_data
			if OS.is_debug_build():
				g_old_data = g.export_data()
			g.clear_content()
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
			var solve_result := solver.full_solve(g2, strategies, func(): return self.cancel_gen or Time.get_ticks_usec() > start_solve + MAX_TIME_PER_SOLVE * US_TO_S)
			#print("Solve result %s" % [SolverModel.SolveResult.find_key(solve_result)])
			match solve_result:
				SolverModel.SolveResult.Unsolvable:
					had_unsolvable_error = true
					# Strategies should ALWAYS just do valid moves, and never "drop" any valid solution
					# Otherwise the uniqueness testing won't work properly
					push_error("Got to unsolvable state, weird. This probably means some strategy is doing an invalid move.")
					if OS.is_debug_build():
						print("This seems unsolvable but shouldn't be")
						print(JSON.stringify(g_old_data))
				SolverModel.SolveResult.SolvedMultiple:
					multiple_solutions +=1
				SolverModel.SolveResult.SolvedUniqueNoGuess:
					too_easy += 1
				SolverModel.SolveResult.GaveUp:
					too_hard += 1
			if solve_result == SolverModel.SolveResult.SolvedUnique:
				total_solve += Time.get_ticks_usec() - start_solve
				g = GridImpl.import_data(g2.export_data(), GridModel.LoadMode.SolutionNoClear)
				found = true
				break
		total_solve += Time.get_ticks_usec() - start_solve
	if found:
		print("Created level after %d tries and %.1fs (%.1fs gen + %.1fs solve) [seed=%d,initial_state=%d,success_state=%d]" % [inner_tries, (Time.get_ticks_usec() - start_time) / US_TO_S, total_gen / US_TO_S, total_solve / US_TO_S, initial_seed, initial_state, success_state])
	else:
		print("Level generation canceled after %d tries and %.1fs (%.1fs gen + %.1fs solve)" % [inner_tries, (Time.get_ticks_usec() - start_time) / US_TO_S, total_gen / US_TO_S, total_solve / US_TO_S])
	return g if found else null

var direct_thread := false

func generate(rng: RandomNumberGenerator, n: int, m: int, apply_hints: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array, force_boats := false) -> GridModel:
	return await generate_with_size(rng, func(_rng): return Vector2i(n, m), apply_hints, gen_options_builder, strategies, forced_strategies, force_boats)

# gen_size takes an rng and returns a Vector2i with (n, m)
# apply_hints takes (rng, grid) and should use a Level.HintVisibility to modify the level hints
# gen_options_builder takes rng and returns a Generator.Options
# If forced_str is empty, the level is generated as "interesting" (SolvedUnique)
func generate_with_size(rng: RandomNumberGenerator, gen_size: Callable, apply_hints: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array, force_boats := false) -> GridModel:
	cancel_gen = false
	had_unsolvable_error = false
	tries = 0
	if direct_thread:
		return _inner_gen_level(rng, gen_size, apply_hints, gen_options_builder, strategies, forced_strategies, force_boats)
	gen_thread.start(func(): return _inner_gen_level(rng, gen_size, apply_hints, gen_options_builder, strategies, forced_strategies, force_boats))
	return await Global.wait_for_thread(gen_thread)

func running() -> bool:
	return gen_thread.is_alive() and gen_thread.is_started()

func cancel() -> void:
	cancel_gen = true
