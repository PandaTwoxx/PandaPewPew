extends Control
## Main menu: host a game or join one.

var _address: LineEdit
var _port: LineEdit
var _status: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#6aa84f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(300, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)

	var title := Label.new()
	title.text = "PandaPewPew"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#fff3cf"))
	title.add_theme_color_override("font_outline_color", Color("#5b1d1a"))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Server address"
	box.add_child(_address)

	_port = LineEdit.new()
	_port.text = str(Net.DEFAULT_PORT)
	_port.placeholder_text = "Port"
	box.add_child(_port)

	var host_btn := Button.new()
	host_btn.text = "Host"
	host_btn.pressed.connect(_on_host)
	box.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(_on_join)
	box.add_child(join_btn)

	var sub := Label.new()
	sub.text = "Farmyard Fracas"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.move_child(sub, 1)

	_status = Label.new()
	box.add_child(_status)

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)


func _exit_tree() -> void:
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_failed):
		multiplayer.connection_failed.disconnect(_on_failed)


func _port_value() -> int:
	var p := _port.text.to_int()
	return p if p > 0 else Net.DEFAULT_PORT


func _on_host() -> void:
	var err := Net.host(_port_value())
	if err != OK:
		_status.text = "Host failed (error %d)" % err
		return
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_join() -> void:
	var err := Net.join(_address.text.strip_edges(), _port_value())
	if err != OK:
		_status.text = "Join failed (error %d)" % err
		return
	_status.text = "Connecting..."


func _on_connected() -> void:
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_failed() -> void:
	Net.leave()
	_status.text = "Connection failed"
