extends Node


signal money_changed
signal autosave_changed
# Config file path
const CONFIG_PATH: String = "user://config.cfg"
# Config sections/keys
const SCORES = "Scores"
const MONEY = "money"
const DIAMONDS = "diamonds"
const GOLD = "gold"
const SOUND_SECTION: String = "Sound"
const MUTE: String = "mute"
const SFX_VOLUME: String = "sfx_volume"
const VOICE_VOLUME: String = "voice_volume"
const AUTOSAVE_SECTION: String = "Autosave"
const AUTOSAVE_ENABLED: String = "autosave_enabled"
const AUTOSAVE_INTERVAL: String = "autosave_interval"
# Config values
var money: int = 0
var diamonds: int = 0
var gold: int = 0
var mute: bool = false setget _set_mute
var sfx_volume: float = 1.0 setget _set_sfx_volume
var voice_volume: float = 1.0 setget _set_voice_volume
var autosave_enabled: bool = true setget _set_autosave_enabled
var autosave_interval: float = 2.0 setget _set_autosave_interval


func _ready():
	read()
	# warning-ignore:return_value_discarded
	connect("tree_exiting", self, "save")


func collect_diamond():
	money += 1000
	diamonds += 1
	emit_signal("money_changed")


func collect_gold():
	money += 500
	gold += 1
	emit_signal("money_changed")


func read():
	var config_file = ConfigFile.new()
	config_file.load(CONFIG_PATH)
	gold = config_file.get_value(SCORES, GOLD, gold)
	diamonds = config_file.get_value(SCORES, DIAMONDS, diamonds)
	money = config_file.get_value(SCORES, MONEY, (diamonds * 1000) + (gold * 500))
	mute = config_file.get_value(SOUND_SECTION, MUTE, mute)
	sfx_volume = config_file.get_value(SOUND_SECTION, SFX_VOLUME, sfx_volume)
	voice_volume = config_file.get_value(SOUND_SECTION, VOICE_VOLUME, voice_volume)
	autosave_enabled = config_file.get_value(AUTOSAVE_SECTION, AUTOSAVE_ENABLED, autosave_enabled)
	autosave_interval = config_file.get_value(AUTOSAVE_SECTION, AUTOSAVE_INTERVAL, autosave_interval)


func save():
	var config_file = ConfigFile.new()
	config_file.set_value(SCORES, MONEY, money)
	config_file.set_value(SCORES, DIAMONDS, diamonds)
	config_file.set_value(SCORES, GOLD, gold)
	config_file.set_value(SOUND_SECTION, MUTE, mute)
	config_file.set_value(SOUND_SECTION, SFX_VOLUME, sfx_volume)
	config_file.set_value(SOUND_SECTION, VOICE_VOLUME, voice_volume)
	config_file.set_value(AUTOSAVE_SECTION, AUTOSAVE_ENABLED, autosave_enabled)
	config_file.set_value(AUTOSAVE_SECTION, AUTOSAVE_INTERVAL, autosave_interval)
	config_file.save(CONFIG_PATH)


func _set_mute(value: bool):
	mute = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)


func _set_sfx_volume(value: float):
	sfx_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(value))


func _set_voice_volume(value: float):
	voice_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear2db(value))


func _set_autosave_enabled(value: bool):
	autosave_enabled = value
	emit_signal("autosave_changed")


func _set_autosave_interval(value: float):
	autosave_interval = value
	emit_signal("autosave_changed")
