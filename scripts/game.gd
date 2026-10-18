extends Node2D
## Arena. The server runs the match (spawning, damage, respawns, mode rules); MultiplayerSpawners
## and the replicated MatchState carry the results to clients. Map and mode come from Net on the
## server and are sent to each client when it joins.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const SPLAT := preload("res://scripts/splat.gd")
const MapDefs := preload("res://scripts/map_defs.gd")
const ModeDefs := preload("res://scripts/mode_defs.gd")
const MatchStateScript := preload("res://scripts/match_state.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Hud := preload("res://scripts/hud.gd")

const RESPAWN_DELAY := 3.0
const SPAWN_SHIELD := 2.0
const END_DELAY := 8.0  ## seconds the result is shown before the next match starts

var map_id := ""
var mode_id := ""
var map := {}
var arena := Rect2(0, 0, 1600, 900)
var state: Node
var mode: RefCounted  ## server only
var hud: CanvasLayer

var _time_left := 0.0
var _end_left := 0.0

@onready var players: Node2D = $Players
@onready var bullets: Node2D = $Bullets
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var bullet_spawner: MultiplayerSpawner = $BulletSpawner


func _ready() -> void:
	# Spawn functions must be set on every peer so replicated spawns can be built.
	player_spawner.spawn_function = _make_player
	bullet_spawner.spawn_function = _make_bullet
	RenderingServer.set_default_clear_color(Color("#4a7c3a"))

	state = MatchStateScript.new()
	state.name = "MatchState"
	add_child(state)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	multiplayer.server_disconnected.connect(_to_menu)

	if multiplayer.is_server():
		# Clients only receive match state once they have told us their scene is ready.
		state.sync.public_visibility = false
		multiplayer.peer_disconnected.connect(_remove_player)
		_load_map(Net.map_id, Net.mode_id)
		_start_match()
		if not Net.dedicated:
			_add_player(1)
	else:
		# Ask to join only once this scene exists, so the spawn path resolves.
		_request_join.rpc_id(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


func _to_menu() -> void:
	Net.leave()
	get_tree().change_scene_to_file(Net.MENU_SCENE)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or mode == null:
		return
	if state.phase == state.PLAYING:
		_time_left -= delta
		state.time_left = maxi(ceili(_time_left), 0)
		if _time_left <= 0.0:
			mode.on_time_up()
		else:
			mode.tick(delta)
	else:
		_end_left -= delta
		if _end_left <= 0.0:
			_start_match()


# --- Joining -----------------------------------------------------------------

@rpc("any_peer", "reliable")
func _request_join() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_init_client.rpc_id(id, map_id, mode_id)
	state.sync.set_visibility_for(id, true)
	_add_player(id)


@rpc("authority", "reliable")
func _init_client(new_map: String, new_mode: String) -> void:
	_load_map(new_map, new_mode)


func _add_player(id: int) -> void:
	if players.has_node(str(id)):
		return
	var team := _next_team()
	player_spawner.spawn({"id": id, "pos": pick_spawn(team, id), "team": team})


func _remove_player(id: int) -> void:
	var p := players.get_node_or_null(str(id))
	if p:
		if mode:
			mode.on_player_removed(p)
		p.queue_free()


## Smaller team gets the next player (random on ties); -1 in free-for-all modes.
func _next_team() -> int:
	if not ModeDefs.uses_teams(mode_id):
		return -1
	var counts := [0, 0]
	for p in players_list():
		if p.team >= 0:
			counts[p.team] += 1
	if counts[0] == counts[1]:
		return randi() % 2
	return 0 if counts[0] < counts[1] else 1


func _make_player(data: Dictionary) -> Node:
	var p := PLAYER_SCENE.instantiate()
	p.name = str(data.id)
	p.position = data.pos
	p.team = data.team
	return p


# --- Match flow (server) -----------------------------------------------------

func _start_match() -> void:
	mode = ModeDefs.create(mode_id, self)
	mode.setup()
	_time_left = mode.time_limit
	_end_left = 0.0
	state.time_left = ceili(_time_left)
	state.winner = -1
	state.phase = state.PLAYING
	for p in players_list():
		p.kills = 0
		p.deaths = 0
		p.carrying = false
		_respawn(p)


## winner: team index (team modes) or peer id (free-for-all); -2 = draw.
func end_match(winner: int) -> void:
	if state.phase == state.ENDED:
		return
	state.winner = winner
	state.phase = state.ENDED
	_end_left = END_DELAY


## Server: applies a bullet hit. Returns false when the bullet should pass through
## (the shooter themself or a teammate), true when it is absorbed.
func hit_player(victim: Node, shooter_id: int, amount: int) -> bool:
	if victim.name.to_int() == shooter_id:
		return false
	var shooter := get_player(shooter_id)
	if shooter and victim.team >= 0 and shooter.team == victim.team:
		return false
	if not victim.alive or victim.shielded or state.phase != state.PLAYING:
		return true
	victim.health -= amount
	if victim.health <= 0:
		_kill(victim, shooter)
	return true


func _kill(victim: Node, killer: Node) -> void:
	victim.health = 0
	victim.alive = false
	victim.deaths += 1
	if killer:
		killer.kills += 1
	mode.on_kill(victim, killer)
	announce("%s eliminated %s" % [killer.display_name() if killer else "Someone", victim.display_name()],
		killer.team if killer else -1)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn_id.bind(victim.name.to_int()))


func _respawn_id(id: int) -> void:
	var p := get_player(id)
	if p and not p.alive and state.phase == state.PLAYING:
		_respawn(p)


func _respawn(p: Node) -> void:
	var pos := pick_spawn(p.team, p.name.to_int())
	p.health = p.MAX_HEALTH
	p.alive = true
	p.shielded = true
	p.position = pos
	p.reset_gun()
	p.respawn_at.rpc_id(p.name.to_int(), pos)
	get_tree().create_timer(SPAWN_SHIELD).timeout.connect(_drop_shield.bind(p.name.to_int()))


func _drop_shield(id: int) -> void:
	var p := get_player(id)
	if p:
		p.shielded = false


## Picks the team spawn farthest from living enemies (any spawn in free-for-all).
func pick_spawn(team: int, for_id: int = 0) -> Vector2:
	var spawns: Array = map.spawns
	var pts: Array = Array(spawns[team]) if team >= 0 else Array(spawns[0]) + Array(spawns[1])
	var threats: Array[Vector2] = []
	for p in players_list():
		if p.alive and p.name.to_int() != for_id and (team < 0 or p.team != team):
			threats.append(p.global_position)
	var best: Vector2 = pts[randi() % pts.size()]
	var best_d := -1.0
	for pt in pts:
		var d := INF
		for t in threats:
			d = minf(d, pt.distance_to(t))
		d += randf() * 150.0  # break ties and avoid always using the same spot
		if d > best_d:
			best_d = d
			best = pt
	return best


# --- Queries -----------------------------------------------------------------

func players_list() -> Array:
	return players.get_children()


func get_player(id: int) -> Node:
	return players.get_node_or_null(str(id))


func local_player() -> Node:
	return get_player(multiplayer.get_unique_id())


func team_name(team: int) -> String:
	return ModeDefs.TEAM_NAMES[team]


## Server: shows `text` in every peer's feed, tinted with `team`'s colour (-1 = white).
func announce(text: String, team: int = -1) -> void:
	_announce.rpc(text, team)


@rpc("authority", "call_local", "reliable")
func _announce(text: String, team: int) -> void:
	hud.push_feed(text, ModeDefs.team_color(team))


# --- Spawning / world --------------------------------------------------------

func splat(pos: Vector2, color: Color) -> void:
	var s := Node2D.new()
	s.set_script(SPLAT)
	s.color = color
	s.position = pos
	add_child(s)


## Server-only: fire a bullet from `pos` along `dir`.
func spawn_bullet(pos: Vector2, dir: Vector2, shooter: int) -> void:
	bullet_spawner.spawn({"pos": pos, "dir": dir, "shooter": shooter})


func _make_bullet(data: Dictionary) -> Node:
	var b := BULLET_SCENE.instantiate()
	b.position = data.pos
	b.direction = data.dir
	b.shooter = data.shooter
	return b


func _load_map(new_map: String, new_mode: String) -> void:
	if not map.is_empty():
		return
	map_id = new_map if MapDefs.has_map(new_map) else MapDefs.ORDER[0]
	mode_id = new_mode if ModeDefs.has_mode(new_mode) else ModeDefs.ORDER[0]
	map = MapDefs.get_map(map_id)
	arena = Rect2(Vector2.ZERO, map.size)
	_build_field()
	_build_walls()
	for layer in ["ground", "air"]:
		var o := Objectives.new()
		o.game = self
		o.layer = layer
		add_child(o)
	for p in players_list():
		p.apply_arena()


func _build_field() -> void:
	var f := Node2D.new()
	f.set_script(preload("res://scripts/field.gd"))
	f.size = arena.size
	f.theme_def = map.theme
	add_child(f)


func _build_walls() -> void:
	var t := 20.0
	# Invisible boundary colliders just outside the visible fence.
	for r in [
		Rect2(-t, -t, arena.size.x + 2 * t, t + 8),
		Rect2(-t, arena.size.y - 8, arena.size.x + 2 * t, t + 8),
		Rect2(-t, 0, t + 8, arena.size.y),
		Rect2(arena.size.x - 8, 0, t + 8, arena.size.y),
	]:
		_add_prop("wall", r)
	for prop in map.props:
		_add_prop(prop[0], prop[1])


func _add_prop(kind: String, rect: Rect2) -> void:
	var p := StaticBody2D.new()
	p.set_script(preload("res://scripts/prop.gd"))
	p.setup(kind, rect)
	add_child(p)
