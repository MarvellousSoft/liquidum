extends Control

var id: int

@onready var Open: Button = %Open
@onready var OngoingSolution = %OngoingSolution
var tween_check: Tween

func _ready() -> void:
	if not SteamManager.enabled or id <= 0:
		Open.disabled = true
		return
	Open.text = "NOT_INSTALLED"
	Open.disabled = true
	OngoingSolution.hide()
	try_check_download()

func _on_vote_received(up: bool, down: bool, _skipped: bool) -> void:
	%ThumbUp.disabled = false
	%ThumbDown.disabled = false
	%ThumbUp.button_pressed = up
	%ThumbDown.button_pressed = down


func load_level() -> LevelData:
	var info: Dictionary = SteamManager.steam.getItemInstallInfo(id)
	if not info.ret:
		return null
	var folder := ProjectSettings.localize_path(info.folder)
	return FileManager.load_workshop_level(folder)

func get_vote() -> void:
	if Open.disabled or not SteamManager.enabled:
		return
	Steam.getUserItemVote(id)
	var ret: Array = await Steam.get_item_vote_result
	if ret[0] == Steam.RESULT_OK:
		assert(ret[1] == id)
		_on_vote_received(ret[2], ret[3], ret[4])

func try_check_download() -> void:
	var level := load_level()
	if level != null:
		Open.text = level.full_name
		Open.disabled = false
		var save := FileManager.load_level(str(id))
		OngoingSolution.visible = save != null and not save.is_solution_empty()
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


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
