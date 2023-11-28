extends Control

var id: int

@onready var Open: Button = $Open
var tween_check: Tween

func _ready() -> void:
	if not SteamManager.enabled or id <= 0:
		Open.disabled = true
		return
	Open.text = "Not installed"
	Open.disabled = true
	try_check_download()

func load_level() -> LevelData:
	var info := Steam.getItemInstallInfo(id)
	var folder := ProjectSettings.localize_path(info.folder)
	if info.ret == true and DirAccess.dir_exists_absolute(folder):
		return FileManager.load_workshop_level(folder)
	return null

func try_check_download() -> void:
	var level := load_level()
	if level != null:
		Open.text = level.full_name
		Open.disabled = false
	else:
		Steam.downloadItem(id, true)



func _on_open_pressed() -> void:
	var level_data := load_level()
	if level_data == null:
		return
	var level := Global.create_level(GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution), str(id))
	TransitionManager.push_scene(level)
