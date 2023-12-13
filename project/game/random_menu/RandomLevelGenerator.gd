class_name RandomLevelGenerator

var gen_thread := Thread.new()
var cancel_gen := false

func _inner_gen_level(rng: RandomNumberGenerator, hints_builder: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array) -> GridModel:
	var g: GridModel = null
	var solver := SolverModel.new()
	var found := false
	var start_time := Time.get_unix_time_from_system()
	var total_gen := 0.0
	var total_solve := 0.0
	var tries := 0
	for i in 1000:
		if cancel_gen:
			break
		var hints: Level.HintVisibility = hints_builder.call(rng)
		var gen_options: int = gen_options_builder.call(rng)
		var start_gen := Time.get_unix_time_from_system()
		g = Generator.new(rng.randi(), bool(gen_options & 1), bool(gen_options & 2)).generate(hints.row.size(), hints.col.size())
		total_gen += Time.get_unix_time_from_system() - start_gen
		g.set_auto_update_hints(false)
		for j in 3:
			if cancel_gen:
				break
			hints.apply_to_grid(g)
			var start_solve := Time.get_unix_time_from_system()
			tries += 1
			if not forced_strategies.is_empty():
				var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Solution)
				if solver.can_solve_with_strategies(g2, strategies, forced_strategies):
					total_solve += Time.get_unix_time_from_system() - start_solve
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
				if solver.full_solve(g2, strategies, func(): return self.cancel_gen or Time.get_unix_time_from_system() > start_solve + 3) == SolverModel.SolveResult.SolvedUnique:
					total_solve += Time.get_unix_time_from_system() - start_solve
					g = GridImpl.import_data(g2.export_data(), GridModel.LoadMode.SolutionNoClear)
					found = true
					break
			total_solve += Time.get_unix_time_from_system() - start_solve
			# Let's retry with the same grid but different visibility
			if j < 2:
				hints = hints_builder.call(rng)
		if found:
			g.prettify_hints()
			print("Created level after %d tries and %.1fs (%.1fs gen + %.1fs solve)" % [tries, Time.get_unix_time_from_system() - start_time, total_gen, total_solve])
			break
	return g if not cancel_gen else null

func generate(rng: RandomNumberGenerator, hints_builder: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array) -> GridModel:
	cancel_gen = false
	gen_thread.start(func(): return _inner_gen_level(rng, hints_builder, gen_options_builder, strategies, forced_strategies))
	return await Global.wait_for_thread(gen_thread)

func running() -> bool:
	return gen_thread.is_alive() and gen_thread.is_started()

func cancel() -> void:
	cancel_gen = true
