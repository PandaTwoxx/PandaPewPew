extends Node2D
## Arena. The server spawns players and bullets; MultiplayerSpawners replicate them.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const ARENA := Rect2(0, 0, 1600, 900)

@onready var players: Node2D = $Players
@onready var bullets: Node2D = $Bullets
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var bullet_spawner: MultiplayerSpawner = $BulletSpawner


func _ready() -> void:
	# Spawn functions must be set on every peer so replicated spawns can be built.
	player_spawner.spawn_function = _make_player
	bullet_spawner.spawn_function = _make_bullet
	_build_walls()
	_build_hud()
	multiplayer.server_disconnected.connect(_to_menu)

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_remove_player)
		if not Net.dedicated:
			_add_player(1)
	else:
		# Ask for a player only once this scene exists, so the spawn path resolves.
		_request_spawn.rpc_id(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


func _to_menu() -> void:
	Net.leave()
	get_tree().change_scene_to_file(Net.MENU_SCENE)


@rpc("any_peer", "reliable")
func _request_spawn() -> void:
	if multiplayer.is_server():
		_add_player(multiplayer.get_remote_sender_id())


func _add_player(id: int) -> void:
	if players.has_node(str(id)):
		return
	player_spawner.spawn({"id": id, "pos": random_spawn_point()})


func _remove_player(id: int) -> void:
	var p := players.get_node_or_null(str(id))
	if p:
		p.queue_free()


func random_spawn_point() -> Vector2:
	return Vector2(randf_range(100, ARENA.size.x - 100), randf_range(100, ARENA.size.y - 100))


func _make_player(data: Dictionary) -> Node:
	var p := PLAYER_SCENE.instantiate()
	p.name = str(data.id)
	p.position = data.pos
	return p


## Server-only: fire a bullet from `pos` along `dir`.
func spawn_bullet(pos: Vector2, dir: Vector2, shooter: int) -> void:
	bullet_spawner.spawn({"pos": pos, "dir": dir, "shooter": shooter})


func _make_bullet(data: Dictionary) -> Node:
	var b := BULLET_SCENE.instantiate()
	b.position = data.pos
	b.direction = data.dir
	b.shooter = data.shooter
	return b


func _build_walls() -> void:
	var t := 20.0
	var rects := [
		Rect2(-t, -t, ARENA.size.x + 2 * t, t),
		Rect2(-t, ARENA.size.y, ARENA.size.x + 2 * t, t),
		Rect2(-t, 0, t, ARENA.size.y),
		Rect2(ARENA.size.x, 0, t, ARENA.size.y),
		Rect2(500, 300, 200, 40),
		Rect2(900, 560, 40, 200),
	]
	for r in rects:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		shape.shape = rs
		body.position = r.position + r.size / 2
		body.add_child(shape)
		var vis := ColorRect.new()
		vis.color = Color(0.3, 0.3, 0.35)
		vis.size = r.size
		vis.position = -r.size / 2
		body.add_child(vis)
		add_child(body)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.position = Vector2(8, 8)
	label.text = "WASD move, mouse aim, click shoot, Esc leave" + (
		"  [dedicated server]" if Net.dedicated else "")
	layer.add_child(label)
	add_child(layer)
