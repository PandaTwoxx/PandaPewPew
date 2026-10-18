extends Node
## Networking autoload: owns the ENet peer and registers input actions.
## Dedicated server: godot --headless -- --server [--port=7777]

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 32
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main.tscn"

var dedicated := false


func _ready() -> void:
	_register_inputs()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var port := DEFAULT_PORT
		for a in args:
			if a.begins_with("--port="):
				port = a.get_slice("=", 1).to_int()
		dedicated = true
		if host(port) == OK:
			print("Dedicated server listening on port ", port)
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		else:
			push_error("Could not start server on port %d" % port)
			get_tree().quit(1)


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err


func leave() -> void:
	multiplayer.multiplayer_peer = null


func _register_inputs() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
