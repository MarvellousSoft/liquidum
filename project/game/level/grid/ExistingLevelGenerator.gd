class_name ExistingLevelGenerator
extends Generator

class Options extends Generator.Options:
    var dir_name: String
    func _init(dir_name_: String) -> void:
        dir_name = dir_name_
    func build(rseed: int) -> Generator:
        return ExistingLevelGenerator.new(rseed, self)

static func custom_builder(dir_name: String) -> Options:
    return Options.new(dir_name)

var loaded_grids: Array[LevelData] = []
        
func _init(rseed_: int, opts_: Options) -> void:
    rng.seed = rseed_
    opts = opts_
    var level_count := 0
    while FileManager.has_flavor_seed(opts.dir_name, level_count + 1):
        level_count += 1
    assert(level_count > 0)
    loaded_grids.resize(level_count)

func load_grid() -> GridModel:
    var i := rng.randi_range(0, loaded_grids.size() - 1)
    if loaded_grids[i] == null:
        loaded_grids[i] = FileManager.load_flavor_seed(opts.dir_name, i + 1)
    var grid := GridImpl.import_data(loaded_grids[i].grid_data, GridModel.LoadMode.Editor)
    grid.set_auto_update_hints(false)
    return grid

func generate(_n: int, _m: int) -> GridModel:
    assert(_n == - 1 and _m == - 1, "We're ignoring n and m")
    var g := load_grid()
    if opts.boats:
        randomize_boats(g)
    randomize_water(g, false)
    g.set_auto_update_hints(true)
    return g
    