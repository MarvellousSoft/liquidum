extends Node

const LANGUAGES = [
	{"locale":"en", "name": "English"},
	{"locale":"pt_BR", "name": "Português"},
]

const VERSION := "v0.0.1"
const SHOW_VERSION = true

var options = {
	"master_volume": 0.25,
	"bgm_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": true,
	"previous_windowed_pos": false,
	"locale": 0,
}

func get_locale_idx(locale):
	var idx = 0
	for lang in LANGUAGES:
		if lang.locale == locale:
			return idx
		idx += 1
	push_error("Couldn't find given locale: " + str(locale))


func update_translation():
	TranslationServer.set_locale(LANGUAGES[get_option("locale")].locale)


func get_save_data() -> Dictionary:
	var data = {
		"time": Time.get_datetime_dict_from_system(),
		"version": VERSION,
		"options": options,
	}
	
	return data


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
	
	if Global.is_fullscreen() != options.fullscreen:
		Global.toggle_fullscreen()

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
