extends Node

#Bus
enum {MASTER_BUS, BGM_BUS, SFX_BUS}

#Volume/Fades
const MUTE_DB = -80
const CONTROL_MULTIPLIER = 2.5
const FADEOUT_SPEED = 20
const FADEIN_SPEED = 60
#BGM
const BGM_PATH = "res://database/audio/bgm/"
#SFX
const MAX_SFX_NODES = 2000
const MAX_POS_SFX_NODES = 2000
const MIN_DUPLICATE_INTERVAL = .08
const SFX_PATH = "res://database/audio/sfx/"

@onready var BGMS = {}
@onready var SFXS = {}
@onready var SFX_NODE = $SFXS
@onready var BGMPlayer = $BGMPlayer
@onready var FadeOutBGMPlayer = $FadeOutBGMPlayer

var bgms_last_pos = {}
var just_played_sfxs = {}
var cur_bgm
var cur_sfx_player := 1


func _ready():
	setup_nodes()
	setup_bgms()
	setup_sfxs()


func _process(dt):
	for sfx_name in just_played_sfxs.keys():
		just_played_sfxs[sfx_name] -= dt
		if just_played_sfxs[sfx_name] <= 0.0:
			just_played_sfxs.erase(sfx_name)


func setup_nodes():
	for node in MAX_SFX_NODES:
		var player = AudioStreamPlayer.new()
		player.stream = AudioStreamRandomizer.new()
		player.bus = "SFX"
		SFX_NODE.add_child(player)


func setup_bgms():
	var dir = DirAccess.open(BGM_PATH)
	if dir:
		dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				#Found bgm file, creating data on memory
				BGMS[file_name.replace(".tres", "").replace(".remap", "")] = load(BGM_PATH + file_name.replace(".remap", ""))
				
			file_name = dir.get_next()
	else:
		push_error("An error occurred when trying to access bgms path: " + str(DirAccess.get_open_error()))


func setup_sfxs():
	var dir = DirAccess.open(SFX_PATH)
	if dir:
		dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name != "." and file_name != "..":
				SFXS[file_name.replace(".tres", "").replace(".remap", "")] = load(SFX_PATH + file_name.replace(".remap", ""))
			file_name = dir.get_next()
	else:
		push_error("An error occurred when trying to access sfxs path: " + str(DirAccess.get_open_error()))

##BUS METHODS

#Expects a value between 0 and 1
func set_bus_volume(which_bus: int, value: float):
	var db
	if value <= 0.0:
		db = MUTE_DB
	else:
		db = (1-value)*MUTE_DB/CONTROL_MULTIPLIER
	
	if which_bus in [MASTER_BUS, BGM_BUS, SFX_BUS]:
		AudioServer.set_bus_volume_db(which_bus, db)
	else:
		push_error("Not a valid bus to set volume: " + str(which_bus))


func get_bus_volume(which_bus: int):
	if which_bus in [MASTER_BUS, SFX_BUS, BGM_BUS]:
		return clamp(1.0 - AudioServer.get_bus_volume_db(which_bus)/float(MUTE_DB/CONTROL_MULTIPLIER), 0.0, 1.0)
	else:
		push_error("Not a valid bus to set volume: " + str(which_bus))

##BGM METHODS

func play_bgm(bgm_name, start_from_beginning = false, fade_in_speed_override = false):
	var player = BGMPlayer
	if cur_bgm:
		if start_from_beginning or player.stream != BGMS[bgm_name].asset:
			stop_bgm()
		else:
			return
	
	assert(BGMS.has(bgm_name),"Not a valid bgm name: " + str(bgm_name))
	cur_bgm = bgm_name
	player.stream = BGMS[bgm_name].asset
	player.volume_db = MUTE_DB
	if start_from_beginning:
		player.play(0)
	else:
		player.play(get_bgm_last_pos(bgm_name))
	var fade_speed = fade_in_speed_override
	if not fade_speed:
		fade_speed = FADEIN_SPEED
	var duration = (BGMS[bgm_name].base_db - MUTE_DB)/float(fade_speed)
	var tween = get_tree().create_tween()
	tween.tween_property(player, "volume_db", BGMS[bgm_name].base_db, duration)


func stop_bgm():
	var fadein = BGMPlayer
	if fadein.is_playing():
		var fadeout = FadeOutBGMPlayer
		var pos = fadein.get_playback_position()
		set_bgm_last_pos(cur_bgm, pos)
		var vol = fadein.volume_db
		fadein.stop()
		fadeout.stop()
		fadeout.volume_db = vol
		fadeout.stream = fadein.stream
		fadeout.play(pos)
		var duration = (vol - MUTE_DB)/FADEOUT_SPEED
		var tween = get_tree().create_tween()
		tween.tween_property(fadeout, "volume_db", MUTE_DB, duration)


func get_bgm_last_pos(bgm_name):
	if not bgms_last_pos.has(bgm_name):
		bgms_last_pos[bgm_name] = 0
	return bgms_last_pos[bgm_name]


func set_bgm_last_pos(bgm_name, pos):
	bgms_last_pos[bgm_name] = pos

#SFX methods

func play_sfx(sfx_name: String) -> AudioStreamPlayer:
	if not SFXS.has(sfx_name):
		push_error("Not a valid sfx name: " + sfx_name)
	
	
	#Check if sfxs was just played, don't play it if thats the case
	if just_played_sfxs.has(sfx_name):
		return
	just_played_sfxs[sfx_name] = MIN_DUPLICATE_INTERVAL
	
	var sfx = SFXS[sfx_name]
	var player = get_sfx_player()
	player.stop()
	
	player.stream.add_stream(0, sfx.asset)
	player.volume_db = sfx.base_db + randf_range(-sfx.random_db_var, sfx.random_db_var)
	player.pitch_scale =  sfx.base_pitch
	player.stream.random_pitch = 1.0 + sfx.random_pitch_var
	
	player.play()
	return player


func get_sfx_duration(sfx_name: String):
	if not SFXS.has(sfx_name):
		push_error("Not a valid sfx name: " + sfx_name)
	return SFXS[name].asset.get_length()


func get_sfx_player() -> AudioStreamPlayer:
	var player = $SFXS.get_child(cur_sfx_player)
	cur_sfx_player = (cur_sfx_player+1)%$SFXS.get_child_count()
	return player

