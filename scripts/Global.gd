extends Node


signal diamond_collected
# Config file path
const CONFIG_PATH: String = "user://config.cfg"
# Config sections/keys
const SCORES = "Scores"
const COINS = "coins"
const DIAMONDS = "diamonds"
const COLLECTED_DIAMONDS = "collected_diamonds"
const SOUND_SECTION: String = "Sound"
const MASTER_VOLUME: String = "master_volume"
const SFX_VOLUME: String = "sfx_volume"
const VOICE_VOLUME: String = "voice_volume"
# Config values
var coins: int = 0
var diamonds: int = 0
var collected_diamonds: int = 0
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var voice_volume: float = 1.0


func _ready():
	read()
	# warning-ignore:return_value_discarded
	connect("tree_exiting", self, "save")


func collect_diamond():
	diamonds += 1
	collected_diamonds += 1
	emit_signal("diamond_collected")


func apply():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear2db(voice_volume))


func read():
	var config_file = ConfigFile.new()
	config_file.load(CONFIG_PATH)
	coins = config_file.get_value(SCORES, COINS, coins)
	diamonds = config_file.get_value(SCORES, DIAMONDS, diamonds)
	collected_diamonds = config_file.get_value(SCORES, COLLECTED_DIAMONDS, collected_diamonds)
	master_volume = config_file.get_value(SOUND_SECTION, MASTER_VOLUME, master_volume)
	sfx_volume = config_file.get_value(SOUND_SECTION, SFX_VOLUME, sfx_volume)
	voice_volume = config_file.get_value(SOUND_SECTION, VOICE_VOLUME, voice_volume)
	apply()


func save():
	var config_file = ConfigFile.new()
	config_file.set_value(SCORES, COINS, coins)
	config_file.set_value(SCORES, DIAMONDS, diamonds)
	config_file.set_value(SCORES, COLLECTED_DIAMONDS, collected_diamonds)
	config_file.set_value(SOUND_SECTION, MASTER_VOLUME, master_volume)
	config_file.set_value(SOUND_SECTION, SFX_VOLUME, sfx_volume)
	config_file.set_value(SOUND_SECTION, VOICE_VOLUME, voice_volume)
	config_file.save(CONFIG_PATH)
