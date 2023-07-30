extends Control


const MAIN_SCENE: PackedScene = preload("res://scenes/game/main.tscn")
const WORLDS_DIR: String = "user://worlds_v2/"
onready var name_line_edit: LineEdit = $MarginContainer/Page1/VBoxContainer/NameLineEdit
onready var address_line_edit: LineEdit = $MarginContainer/Page1/VBoxContainer/HBoxContainer/AddressLineEdit
onready var worlds_list: ItemList = $MarginContainer/Page2/WorldsList
onready var message_label: Label = $Message/Label
onready var new_world_name: LineEdit = $NewWorldDialog/GridContainer/NameLineEdit
onready var new_world_type: OptionButton = $NewWorldDialog/GridContainer/TypeOptionButton
onready var delete_confirmation: ConfirmationDialog = $DeleteConfirmation
onready var modal_message: ColorRect = $ModalMessage
onready var animation_player: AnimationPlayer = $AnimationPlayer
export var map_icon: Texture = preload("res://assets/icons/icons8-world-map-96.png")
var worlds: Array = []
var host_on_start = false
var delete_idx


func _ready():
	load_worlds()


func load_worlds():
	var dir = get_dir()
	dir.list_dir_begin()
	var file_name = dir.get_next()
	worlds_list.clear()
	while not file_name == "":
		if not dir.current_is_dir():
			worlds.append(file_name)
			worlds_list.add_item(file_name, map_icon)
		file_name = dir.get_next()


func get_dir() -> Directory:
	var dir = Directory.new()
	if not dir.dir_exists(WORLDS_DIR):
		if not dir.make_dir(WORLDS_DIR) == OK:
			OS.crash("Can't create worlds dir!")
		# Copy world file from older versions
		if dir.file_exists("user://world"):
			if not dir.copy("user://world", "%sdefault" % WORLDS_DIR) == OK:
				OS.alert("Can't copy old world!")
	dir.open(WORLDS_DIR)
	return dir


func open_world(world, type):
	if host_on_start:
		Net.init_server(get_info())
	var main = MAIN_SCENE.instance()
	var game_child = main.get_node("Game")
	game_child.initial_world_path = get_world_path(world)
	game_child.initial_world_type = type
	get_parent().add_child(main)
	queue_free()
	get_tree().current_scene = main


func get_info() -> Dictionary:
	return {
		"name": name_line_edit.text,
	}


func get_world_path(world) -> String:
	return world if world == null else "%s%s" % [WORLDS_DIR, world]


func show_message(msg: String):
	message_label.text = msg
	animation_player.play("message")


func open(index: int):
	open_world(worlds[index], null)


func _on_host_button_pressed():
	host_on_start = true
	animation_player.play("page2")


func _on_connect_button_pressed():
	modal_message.show()
	# warning-ignore:return_value_discarded
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	# warning-ignore:return_value_discarded
	get_tree().connect("connected_to_server", self, "open_world", [null, null])
	Net.init_client(get_info(), address_line_edit.text)


func _on_connection_failed():
	modal_message.hide()
	show_message("Connection failed!")


func _on_new_world_dialog_confirmed():
	var wname = new_world_name.text
	var wtype = new_world_type.text
	if wname == "":
		show_message("Name is empty!")
	else:
		open_world(wname, wtype)


func _on_open_button_pressed():
	var selected_items = worlds_list.get_selected_items()
	if selected_items.size() > 0:
		open(selected_items[0])
	else:
		show_message("No selection!")


func _on_delete_button_pressed():
	var selected_items = worlds_list.get_selected_items()
	if selected_items.size() > 0:
		delete_idx = selected_items[0]
		delete_confirmation.popup_centered()
	else:
		show_message("No selection!")


func _on_delete_confirmation_confirmed():
	var dir = get_dir()
	show_message("Action finished with code %s." % dir.remove(worlds[delete_idx]))
	delete_idx = null
	load_worlds()


func _quit():
	get_tree().quit(0)
