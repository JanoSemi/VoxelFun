extends ConfirmationDialog


onready var mute_button: Button = $GridContainer/MuteButton
onready var sfx_slider: HSlider = $GridContainer/SFXSlider
onready var voice_slider: HSlider = $GridContainer/VoiceSlider
onready var autosave_check_box: CheckBox = $GridContainer/AutosaveCheckBox
onready var autosave_spin_box: SpinBox = $GridContainer/AutosaveSpinBox
onready var load_radius_spin_box: SpinBox = $GridContainer/LoadRadiusSpinBox
onready var chunk_height_spin_box: SpinBox = $GridContainer/ChunkHeightSpinBox


func _on_confirmed():
	Global.mute = mute_button.pressed
	Global.sfx_volume = sfx_slider.value
	Global.voice_volume = voice_slider.value
	Global.autosave_enabled = autosave_check_box.pressed
	Global.autosave_interval = autosave_spin_box.value
	Global.load_radius = int(load_radius_spin_box.value)
	Global.CHUNK_DIMENSION.y = chunk_height_spin_box.value
	Global.save()


func _on_about_to_show():
	Global.read()
	mute_button.pressed = Global.mute
	sfx_slider.value = Global.sfx_volume
	voice_slider.value = Global.voice_volume
	autosave_check_box.pressed = Global.autosave_enabled
	autosave_spin_box.value = Global.autosave_interval
	load_radius_spin_box.value = Global.load_radius
	chunk_height_spin_box.value = Global.CHUNK_DIMENSION.y


func _on_mute_button_toggled(button_pressed: bool):
	mute_button.text = "Yes" if button_pressed else "No"
