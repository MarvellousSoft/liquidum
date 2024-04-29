class_name RandomLevelGenerator

const MAX_TIME_PER_SOLVE = 30.0
const US_TO_S := 1000000.0

var gen_thread := Thread.new()
var cancel_gen := false
# State of the RNG right before generating a successful level
# Can be used to generate it very quickly
var success_state: int

func _init() -> void:
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
	var tries := 0
	for i in 1000:
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
		assert(g.are_hints_satisfied())
		var start_solve := Time.get_ticks_usec()
		tries += 1
		if not forced_strategies.is_empty():
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Solution)
			if solver.can_solve_with_strategies(g2, strategies, forced_strategies):
				total_solve += Time.get_ticks_usec() - start_solve
				g2.force_editor_mode(false)
				g2.clear_content()
				solver.apply_strategies(g2, strategies + forced_strategies)
				assert(g2.are_hints_satisfied())
				g = g2
				found = true
				break
		else:
			g.clear_content()
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
			if solver.full_solve(g2, strategies, func(): return self.cancel_gen or Time.get_ticks_usec() > start_solve + MAX_TIME_PER_SOLVE * US_TO_S) == SolverModel.SolveResult.SolvedUnique:
				total_solve += Time.get_ticks_usec() - start_solve
				g = GridImpl.import_data(g2.export_data(), GridModel.LoadMode.SolutionNoClear)
				found = true
				break
		total_solve += Time.get_ticks_usec() - start_solve
	if found:
		print("Created level after %d tries and %.1fs (%.1fs gen + %.1fs solve) [seed=%d,initial_state=%d,success_state=%d]" % [tries, (Time.get_ticks_usec() - start_time) / US_TO_S, total_gen / US_TO_S, total_solve / US_TO_S, initial_seed, initial_state, success_state])
	else:
		print("Level generation canceled after %d tries and %.1fs (%.1fs gen + %.1fs solve)" % [tries, (Time.get_ticks_usec() - start_time) / US_TO_S, total_gen / US_TO_S, total_solve / US_TO_S])
	return g if found else null

func generate(rng: RandomNumberGenerator, n: int, m: int, apply_hints: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array, force_boats := false) -> GridModel:
	return await generate_with_size(rng, func(_rng): return Vector2i(n, m), apply_hints, gen_options_builder, strategies, forced_strategies, force_boats)

# gen_size takes an rng and returns a Vector2i with (n, m)
# apply_hints takes (rng, grid) and should use a Level.HintVisibility to modify the level hints
# gen_options_builder takes rng and returns a Generator.Options
# If forced_str is empty, the level is generated as "interesting" (SolvedUnique)
func generate_with_size(rng: RandomNumberGenerator, gen_size: Callable, apply_hints: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array, force_boats := false) -> GridModel:
	cancel_gen = false
	gen_thread.start(func(): return _inner_gen_level(rng, gen_size, apply_hints, gen_options_builder, strategies, forced_strategies, force_boats))
	return await Global.wait_for_thread(gen_thread)

func running() -> bool:
	return gen_thread.is_alive() and gen_thread.is_started()

func cancel() -> void:
	cancel_gen = true
