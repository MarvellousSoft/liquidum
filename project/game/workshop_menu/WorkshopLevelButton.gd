class_name WorkshopLevelButton
extends Control

var id: int

@onready var Open: LevelButton = %Open
#@onready var OngoingSolution = %OngoingSolution
var tween_check: Tween

func _ready() -> void:
	if not SteamManager.enabled or id <= 0:
		Open.disabled = true
		return
	var level := load_level()
	Open.setup_workshop(level, id)
	if level == null:
		SteamManager.steam.downloadItem(id, true)
	#Open.text = "NOT_INSTALLED"



func _on_vote_received(up: bool, down: bool, _skipped: bool) -> void:
	%ThumbUp.disabled = false
	%ThumbDown.disabled = false
	%ThumbUp.button_pressed = up
	%ThumbDown.button_pressed = down


static func load_level_from_id(w_id: int) -> LevelData:
	var info: Dictionary = SteamManager.steam.getItemInstallInfo(w_id)
	if not info.ret:
		return null
	var folder := ProjectSettings.localize_path(info.folder)
	return FileManager.load_workshop_level(folder)

func load_level() -> LevelData:
	return WorkshopLevelButton.load_level_from_id(id)

func get_vote() -> void:
	if Open.disabled or not SteamManager.enabled:
		return
	SteamManager.steam.getUserItemVote(id)
	var ret: Array = await SteamManager.steam.get_item_vote_result
	if ret[0] == SteamManager.steam.RESULT_OK:
		assert(ret[1] == id)
		_on_vote_received(ret[2], ret[3], ret[4])


static func _level_completed(info: Level.WinInfo) -> void:
	if info.first_win and SteamManager.enabled:
		SteamStats.increment_workshop()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_thumb_toggled(now_pressed: bool, up: bool) -> void:
	if not now_pressed:
		# No going back
		if up:
			%ThumbUp.set_pressed_no_signal(true)
		else:
			%ThumbDown.set_pressed_no_signal(true)
	else:
		if up:
			%ThumbDown.set_pressed_no_signal(false)
		else:
			%ThumbUp.set_pressed_no_signal(false)
		SteamManager.steam.setUserItemVote(id, up)
		var ret: Array = await SteamManager.steam.set_user_item_vote
		if ret[0] != SteamManager.steam.RESULT_OK:
			push_warning("Failed to vote")
