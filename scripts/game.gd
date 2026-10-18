extends Node2D
## Arena. The server spawns players and bullets; MultiplayerSpawners replicate them.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const ARENA := Rect2(0, 0, 1600, 900)
const SPLAT := preload("res://scripts/splat.gd")

var _blocked: Array[Rect2] = []

@onready var players: Node2D = $Players
@onready var bullets: Node2D = $Bullets
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var bullet_spawner: MultiplayerSpawner = $BulletSpawner


func _ready() -> void:
	# Spawn functions must be set on every peer so replicated spawns can be built.
	player_spawner.spawn_function = _make_player
	bullet_spawner.spawn_function = _make_bullet
	RenderingServer.set_default_clear_color(Color("#4a7c3a"))
	_build_field()
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
	var p := Vector2.ZERO
	for i in 30:
		p = Vector2(randf_range(100, ARENA.size.x - 100), randf_range(100, ARENA.size.y - 100))
		var ok := true
		for r in _blocked:
			if r.grow(30).has_point(p):
				ok = false
				break
		if ok:
			break
	return p


func splat(pos: Vector2, color: Color) -> void:
	var s := Node2D.new()
	s.set_script(SPLAT)
	s.color = color
	s.position = pos
	add_child(s)


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


func _build_field() -> void:
	var f := Node2D.new()
	f.set_script(preload("res://scripts/field.gd"))
	add_child(f)


func _build_walls() -> void:
	var t := 20.0
	# Invisible boundary colliders just outside the visible fence.
	for r in [
		Rect2(-t, -t, ARENA.size.x + 2 * t, t + 8),
		Rect2(-t, ARENA.size.y - 8, ARENA.size.x + 2 * t, t + 8),
		Rect2(-t, 0, t + 8, ARENA.size.y),
		Rect2(ARENA.size.x - 8, 0, t + 8, ARENA.size.y),
	]:
		_add_prop("wall", r)
	_add_prop("barn", Rect2(1150, 90, 280, 180))
	_add_prop("hay", Rect2(500, 300, 200, 40))
	_add_prop("hay", Rect2(260, 480, 40, 160))
	_add_prop("fence", Rect2(900, 560, 16, 220))
	_add_prop("fence", Rect2(1150, 700, 260, 16))
	_add_prop("pond", Rect2(340, 660, 170, 170))
	for c in [Vector2(900, 200), Vector2(1380, 520), Vector2(140, 300), Vector2(760, 770), Vector2(680, 110)]:
		_add_prop("tree", Rect2(c - Vector2(38, 38), Vector2(76, 76)))


func _add_prop(kind: String, rect: Rect2) -> void:
	var p := StaticBody2D.new()
	p.set_script(preload("res://scripts/prop.gd"))
	p.setup(kind, rect)
	add_child(p)
	if kind != "wall":
		_blocked.append(rect)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.position = Vector2(8, 8)
	label.add_theme_color_override("font_outline_color", Color("#2b1d0e"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 16)
	label.text = "WASD move, mouse aim, click shoot, Esc leave" + (
		"  [dedicated server]" if Net.dedicated else "")
	layer.add_child(label)
	add_child(layer)
