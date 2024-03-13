class_name ExistingLevelGenerator
extends Generator

class Options extends Generator.Options:
	var dir_name: String
	var mod_max := 1
	var mod_i := 0
	func _init(dir_name_: String) -> void:
		dir_name = dir_name_
	func with_mod_max(mod_max_: int) -> Options:
		mod_max = mod_max_
		return self
	func with_mod_i(mod_i_: int) -> Options:
		mod_i = mod_i_
		return self
	func build(rseed: int) -> Generator:
		return ExistingLevelGenerator.new(rseed, self)

static func custom_builder(dir_name: String) -> Options:
	return Options.new(dir_name)

var loaded_grids: Array[LevelData] = []
		
func _init(rseed_: int, opts_: Options) -> void:
	super(rseed_, opts_)
	var level_count := 0
	while FileManager.has_flavor_seed(opts.dir_name, level_count + 1):
		level_count += 1
	assert(level_count > 0)
	loaded_grids.resize(level_count)

func load_grid() -> GridModel:
	var opt := opts as Options
	var mx: int = (loaded_grids.size() + opt.mod_max - opt.mod_i - 1) / opt.mod_max
	var i: int = opt.mod_i + opt.mod_max * rng.randi_range(0, mx - 1)
	if loaded_grids[i] == null:
		loaded_grids[i] = FileManager.load_flavor_seed(opts.dir_name, i + 1)
	var grid := GridImpl.import_data(loaded_grids[i].grid_data, GridModel.LoadMode.Editor)
	grid.set_auto_update_hints(false)
	if rng.randf() < 0.5:
		grid.mirror_horizontal()
	if rng.randf() < 0.5:
		grid.mirror_vertical()
	for _i in rng.randi_range(0, 3):
		grid.rotate_clockwise()
	return grid

func generate(_n: int, _m: int) -> GridModel:
	assert(_n == - 1 and _m == - 1, "We're ignoring n and m")
	var g := load_grid()
	if opts.boats:
		randomize_boats(g)
	randomize_water(g, false)
	g.set_auto_update_hints(true)
	return g
	
