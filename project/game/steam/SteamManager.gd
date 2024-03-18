extends Node

signal overlay_toggled(on: bool)

var enabled := true
const APP_ID := 2716690
var steam = null
# This is used to globally wipe stats if necessary. Use with care.
const STATS_VERSION := 1

var stats_received := false
var cached_lds := {}

func _init() -> void:
	if not Global.is_mobile and Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
	else:
		enabled = false
		print("Steam is not available.")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if enabled:
		OS.set_environment("SteamAppId", str(APP_ID))
		OS.set_environment("SteamGameId", str(APP_ID))
		var res: Dictionary = SteamManager.steam.steamInit()
		print("Steam init: %s" % res)
		print("Steam running: %s" % SteamManager.steam.isSteamRunning())
		if res.status != SteamManager.steam.RESULT_OK:
			enabled = false
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	SteamManager.steam.dlc_installed.connect(_on_dlc_installed)
	SteamManager.steam.current_stats_received.connect(_stats_received)
	SteamManager.steam.overlay_toggled.connect(_on_overlay_toggled)
	SteamManager.steam.requestCurrentStats()

func _stats_received(game: int, result: int, user: int) -> void:
	if stats_received:
		return
	if STATS_VERSION != SteamManager.steam.getStatInt("version"):
		print("Resetting all stats!")
		SteamManager.steam.resetAllStats(false)
		SteamManager.steam.setStatInt("version", STATS_VERSION)
		SteamManager.steam.storeStats()
		await SteamManager.steam.user_stats_stored
		SteamManager.steam.requestCurrentStats()
		return
	print("Steam stats received! (result = %d, game = %d, user = %d)" % [result, game, user])
	stats_received = true
	StatsTracker.instance().update_campaign_stats()

func store_stats() -> void:
	if not SteamManager.enabled:
		return
	if not stats_received:
		SteamManager.steam.requestCurrentStats()
		return
	print("Storing steam stats")
	SteamManager.steam.storeStats()

func _notification(what: int) -> void:
	if not enabled:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		store_stats()
		SteamManager.steam.steamShutdown()


func _process(_dt: float) -> void:
	SteamManager.steam.run_callbacks()

class UploadResult:
	var id: int
	var success: bool
	func _init(id_: int, success_: bool) -> void:
		id = id_
		success = success_

var uploading := false

func upload_ugc_item(id: int, title: String, description: String, dir: String, preview_file: String, tags: Array[String]) -> UploadResult:
	if uploading:
		return UploadResult.new(id, false)
	UploadingToWorkshop.start()
	dir = ProjectSettings.globalize_path(dir)
	preview_file = ProjectSettings.globalize_path(preview_file)
	uploading = true
	if id == -1:
		id = await _create_item_id()
	var success := false
	if id != -1:
		success = await _upload_item(id, title, description, dir, preview_file, tags)
	uploading = false
	UploadingToWorkshop.stop()
	return UploadResult.new(id, success)

func _create_item_id() -> int:
	SteamManager.steam.createItem(SteamManager.APP_ID, SteamManager.steam.WORKSHOP_FILE_TYPE_COMMUNITY)
	var ret: Array = await SteamManager.steam.item_created
	var res: int = ret[0]
	var id: int = ret[1]
	var needs_tos: bool = ret[2]
	if res != SteamManager.steam.RESULT_OK:
		push_error("Failed to create item: %s" % res)
		return -1
	print("Successfully created item %d" % id)
	if needs_tos:
		SteamManager.steam.activateGameOverlayToWebPage("steam://url/CommunityFilePage/%d" % id)
	return id

func _upload_item(id: int, title: String, description: String, dir: String, preview_file: String, tags: Array[String]) -> bool:
	var update_id: int = SteamManager.steam.startItemUpdate(SteamManager.APP_ID, id)
	SteamManager.steam.setItemContent(update_id, dir)
	SteamManager.steam.setItemTitle(update_id, title)
	SteamManager.steam.setItemDescription(update_id, description)
	SteamManager.steam.setItemPreview(update_id, preview_file)
	SteamManager.steam.setItemTags(update_id, tags)
	SteamManager.steam.setItemVisibility(update_id, SteamManager.steam.REMOTE_STORAGE_PUBLISHED_VISIBILITY_PUBLIC)
	SteamManager.steam.submitItemUpdate(update_id, Time.get_datetime_string_from_system(true, true))
	UploadingToWorkshop.update_handle = update_id
	var ret: Array = await SteamManager.steam.item_updated
	var res: int = ret[0]
	var needs_tos: bool = ret[1]
	if res != SteamManager.steam.RESULT_OK:
		push_error("Failed to upload item: %s" % res)
		return false
	if needs_tos:
		SteamManager.steam.activateGameOverlayToWebPage("steam://url/CommunityFilePage/%d" % id)
	print("Successfuly updated item %d" % id)
	return true

func _on_dlc_installed(app_id: int) -> void:
	print("Installed DLC %d" % [app_id])

func _on_overlay_toggled(on: bool, _user_initiated: bool, _app_id: int) -> void:
	overlay_toggled.emit(on)

# Safe to call even if Steam is disabled
func overlay_or_browser(url: String) -> void:
	if not enabled or not steam.isOverlayEnabled():
		OS.shell_open(url)
	else:
		steam.activateGameOverlayToWebPage(url)

func get_or_create_leaderboard(l_name: String, sort_method: int, display_method: int) -> int:
	if not enabled or l_name.is_empty():
		return -1
	if not cached_lds.has(l_name):
		print("find or create: %s asc %s" % [l_name, sort_method == steam.LEADERBOARD_SORT_METHOD_ASCENDING])
		steam.findOrCreateLeaderboard(l_name, sort_method, display_method)
		var ret: Array = await steam.leaderboard_find_result
		if not ret[1]:
			push_warning("Leaderboard not found: %s" % [l_name])
			return -1
		print("Found: %d" % [ret[0]])
		cached_lds[l_name] = ret[0]
	return cached_lds[l_name]

func upload_leaderboard_score(l_id: int, score: int, keep_best: bool, details: LeaderboardDetails) -> void:
	# ALWAYS need to specify ld
	if l_id <= 0 or not enabled:
		return
	steam.uploadLeaderboardScore(score, keep_best, LeaderboardDetails.to_arr(details), l_id)
	var ret: Array = await steam.leaderboard_score_uploaded
	if not ret[0]:
		push_warning("Failed to upload leaderboard entry for %d" % [l_id])