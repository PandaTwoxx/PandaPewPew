extends Node
## Networking autoload: owns the ENet peer, registers input actions,
## and communicates with the Bun.js multiplayer backend for room matchmaking.
## Dedicated server: godot --headless -- --server [--port=7777] [--map=farm] [--mode=kills]

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 32
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
const DEFAULT_BUN_URL := "http://localhost:3000"
const MapDefs := preload("res://scripts/map_defs.gd")
const ModeDefs := preload("res://scripts/mode_defs.gd")

var dedicated := false
## Chosen by whoever hosts; clients are told by the server when they join.
var map_id: String = MapDefs.ORDER[0]
var mode_id: String = ModeDefs.ORDER[0]
var bun_url: String = DEFAULT_BUN_URL
var current_room_code: String = ""
var _heartbeat_timer: Timer


func _ready() -> void:
	_register_inputs()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var port := DEFAULT_PORT
		for a in args:
			if a.begins_with("--port="):
				port = a.get_slice("=", 1).to_int()
			elif a.begins_with("--map="):
				map_id = _checked(a.get_slice("=", 1), MapDefs.has_map(a.get_slice("=", 1)), map_id)
			elif a.begins_with("--mode="):
				mode_id = _checked(a.get_slice("=", 1), ModeDefs.has_mode(a.get_slice("=", 1)), mode_id)
		dedicated = true
		if host(port) == OK:
			print("Dedicated server listening on port ", port)
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		else:
			push_error("Could not start server on port %d" % port)
			get_tree().quit(1)


func set_bun_url(url: String) -> void:
	bun_url = url.strip_edges().trim_suffix("/")


func _checked(value: String, valid: bool, fallback: String) -> String:
	if not valid:
		push_warning("Unknown value '%s', using '%s'" % [value, fallback])
	return value if valid else fallback


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
	_stop_heartbeat()
	current_room_code = ""
	multiplayer.multiplayer_peer = null


# --- BUN.JS BACKEND INTEGRATION ---

func fetch_bun_health() -> Dictionary:
	return await _http_get(bun_url + "/api/health")


func fetch_bun_rooms() -> Array:
	var res = await _http_get(bun_url + "/api/rooms")
	if res.has("rooms") and res["rooms"] is Array:
		return res["rooms"]
	return []


func create_bun_room(room_name: String, port: int, host_name: String = "Panda") -> Dictionary:
	var payload := {
		"name": room_name,
		"hostName": host_name,
		"port": port,
	}
	var res = await _http_post(bun_url + "/api/rooms", payload)
	if res.get("success", false) and res.has("room"):
		current_room_code = res["room"].get("code", "")
		_start_heartbeat(current_room_code)
		return res["room"]
	return {}


func join_bun_room(code: String) -> Dictionary:
	var res = await _http_get(bun_url + "/api/rooms/" + code.to_upper().strip_edges())
	if res.get("success", false) and res.has("room"):
		current_room_code = res["room"].get("code", "")
		return res["room"]
	return {}


func spawn_dedicated_bun_room(room_name: String = "") -> Dictionary:
	var payload := {"name": room_name}
	var res = await _http_post(bun_url + "/api/rooms/dedicated", payload)
	if res.get("success", false) and res.has("room"):
		return res["room"]
	return {}


func _http_get(url: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {}
	var result = await http.request_completed
	http.queue_free()
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] >= 200 and result[1] < 300:
		var json = JSON.parse_string(result[3].get_string_from_utf8())
		if json is Dictionary:
			return json
	return {}


func _http_post(url: String, data: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(data)
	var headers := ["Content-Type: application/json", "Accept: application/json"]
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {}
	var result = await http.request_completed
	http.queue_free()
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] >= 200 and result[1] < 300:
		var json = JSON.parse_string(result[3].get_string_from_utf8())
		if json is Dictionary:
			return json
	return {}


func _start_heartbeat(code: String) -> void:
	_stop_heartbeat()
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = 15.0
	_heartbeat_timer.autostart = true
	_heartbeat_timer.timeout.connect(func():
		if current_room_code != "":
			var count := 1
			if multiplayer.multiplayer_peer:
				count = multiplayer.get_peers().size() + 1
			_http_post(bun_url + "/api/rooms/" + current_room_code + "/heartbeat", {"playerCount": count})
	)
	add_child(_heartbeat_timer)


func _stop_heartbeat() -> void:
	if _heartbeat_timer and is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null


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
