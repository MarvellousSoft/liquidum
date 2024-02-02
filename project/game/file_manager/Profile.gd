extends Node

signal dark_mode_toggled(status: bool)
signal line_info_changed()
signal show_timer_changed(status: bool)
signal allow_mistakes_changed(status: bool)
signal progress_on_unkown_changed(status: bool)

const LANGUAGES = [
	"",
	"en",
	"pt_BR",
]

enum LineInfo {
	None,
	ShowMissing,
	ShowCurrent,
}

var VERSION: String = ProjectSettings.get_setting("application/config/version")
const SHOW_VERSION := true

var options = {
	"master_volume": 0.25,
	"bgm_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": true,
	"window_position": Vector2i(-1, -1),
	"window_size": Vector2i(-1, -1),
	"highlight_grid": true,
	"show_grid_preview": true,
	"locale": 0,
	"dark_mode": false,
	"drag_content": true,
	"invert_mouse": false,
	"line_info": LineInfo.None,
	"vsync": int(DisplayServer.VSYNC_ADAPTIVE),
	"show_timer": true,
	"allow_mistakes": false,
	"progress_on_unknown": false,
}

const STEAM_LANGUAGES := {
	brazilian = "pt_BR",
	english = "en",
}


func _ready():
	dark_mode_toggled.connect(_on_dark_mode_toggled)
	dark_mode_toggled.connect(CursorManager._dark_mode_toggled)


func update_translation() -> void:
	var l_idx: int = get_option("locale")
	var locale: String
	if l_idx == 0:
		if SteamManager.enabled:
			locale = STEAM_LANGUAGES.get(SteamManager.steam.getCurrentGameLanguage(), OS.get_locale())
		else:
			locale = OS.get_locale()
	else:
		locale = LANGUAGES[l_idx]
	TranslationServer.set_locale(locale)


func get_save_data() -> Dictionary:
	var data = {
		"time": Time.get_datetime_dict_from_system(),
		"version": VERSION,
		"options": options,
	}
	return data

func get_vec2i(key: String) -> Vector2i:
	var val = get_option(key)
	if val is String:
		return str_to_var("Vector2i" + val)
	return val

func get_override() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window/size/mode", DisplayServer.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not options.fullscreen:
		cfg.set_value("display", "window/size/initial_position_type", 0)
		var pos := get_vec2i("window_position")
		if pos != Vector2i(-1, -1):
			cfg.set_value("display", "window/size/initial_position", pos)
		var wsize := get_vec2i("window_size")
		if wsize != Vector2i(-1, -1):
			cfg.set_value("display", "window/size/window_width_override", wsize.x)
			cfg.set_value("display", "window/size/window_height_override", wsize.y)
	cfg.set_value("display", "window/vsync/vsync_mode", options.vsync)
	return cfg


func set_save_data(data):
	if data.version != VERSION:
		#Handle version diff here.
		push_warning("Different save version for profile. Its version: " + str(data.version) + " Current version: " + str(Profile.VERSION)) 
		push_warning("Properly updating to new save version")
		#(●◡●)
		push_warning("Profile updated!")
	
	set_data(data, "options", options)
	
	AudioManager.set_bus_volume(AudioManager.MASTER_BUS, options.master_volume)
	AudioManager.set_bus_volume(AudioManager.BGM_BUS, options.bgm_volume)
	AudioManager.set_bus_volume(AudioManager.SFX_BUS, options.sfx_volume)
	
	DisplayServer.window_set_vsync_mode(options.vsync)
	if Global.is_fullscreen() != options.fullscreen:
		Global.toggle_fullscreen()
	if not options.fullscreen:
		var window := get_window()
		var wpos := get_vec2i("window_position")
		if wpos != Vector2i(-1, -1):
			window.position = wpos
		var wsize := get_vec2i("window_size")
		if wsize != Vector2i(-1, -1):
			window.size = wsize
	update_translation()
	dark_mode_toggled.emit(options.dark_mode)

func set_data(data, idx, default_values, ignore_deprecated := false):
	if not data.has(idx):
		return
	
	#Update received data with missing default values
	for key in default_values.keys():
		if not data[idx].has(key):
			data[idx][key] = default_values[key]
			push_warning("Adding new profile entry '" + str(key) + str("' for " + str(idx)))
		elif typeof(default_values[key]) == TYPE_DICTIONARY:
			set_data(data[idx], key, default_values[key])
			
	for key in data[idx].keys():
		#Ignore deprecated values
		if default_values.has(key):
			default_values[key] = data[idx][key]
		elif not ignore_deprecated:
			data[idx].erase(key)
			push_warning("Removing deprecated value '" + str(key) + str("' for " + str(idx)))


func get_option(opt_name):
	assert(options.has(opt_name), "Not a valid option: " + str(opt_name))
	return options[opt_name]


func set_option(opt_name: String, value, should_save := false):
	assert(options.has(opt_name),"Not a valid option: " + str(opt_name))
	options[opt_name] = value
	if should_save:
		FileManager.save_profile()


func _on_dark_mode_toggled(is_dark):
	ProjectSettings.set_setting("gui/theme/custom", Global.get_theme(is_dark))
