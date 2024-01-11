extends Control

var id: int

@onready var Open: Button = $Open
@onready var OngoingSolution = $OngoingSolution
var tween_check: Tween

func _ready() -> void:
	if not SteamManager.enabled or id <= 0:
		Open.disabled = true
		return
	Open.text = "NOT_INSTALLED"
	Open.disabled = true
	OngoingSolution.hide()
	try_check_download()

func load_level() -> LevelData:
	var info: Dictionary = SteamManager.steam.getItemInstallInfo(id)
	if not info.ret:
		return null
	var folder := ProjectSettings.localize_path(info.folder)
	return FileManager.load_workshop_level(folder)


func try_check_download() -> void:
	var level := load_level()
	if level != null:
		Open.text = level.full_name
		Open.disabled = false
		var save := FileManager.load_level(str(id))
		OngoingSolution.visible = save != null and save.is_empty
	else:
		SteamManager.steam.downloadItem(id, true)

func _on_open_pressed() -> void:
	var level_data := load_level()
	if level_data == null:
		return
	var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), str(id), level_data.full_name, level_data.description, ["workshop"])
	level.workshop_id = id
	level.won.connect(_level_completed)
	TransitionManager.push_scene(level)

func _level_completed(info: Level.WinInfo) -> void:
	if info.first_win and SteamManager.enabled:
		SteamStats.increment_workshop()
