extends "res://scripts/modes/game_mode.gd"
## Two teams, one flag each. Carry the enemy flag to your base while your own flag is home.
## Flag f belongs to team f. A dropped flag can be returned by a teammate's touch or on a timer.

const CAPTURE_LIMIT := 3
const PICKUP_RANGE := 38.0
const BASE_RANGE := 55.0
const RETURN_TIME := 15.0

var _dropped := [false, false]
var _return_left := [0.0, 0.0]


func _init() -> void:
	time_limit = 480.0


func setup() -> void:
	_dropped = [false, false]
	_return_left = [0.0, 0.0]
	state.team_scores = PackedInt32Array([0, 0])
	state.flag_pos = PackedVector2Array(game.map.flags)
	state.flag_carrier = PackedInt32Array([0, 0])


func tick(delta: float) -> void:
	for f in 2:
		var carrier: int = state.flag_carrier[f]
		if carrier != 0:
			var c = game.get_player(carrier)
			if c == null or not c.alive:
				_drop(f, state.flag_pos[f] if c == null else c.global_position)
		elif _dropped[f]:
			_return_left[f] -= delta
			if _return_left[f] <= 0.0:
				_return(f, null)
	for p in game.players_list():
		if not p.alive or p.team < 0:
			continue
		for f in 2:
			if state.flag_carrier[f] == 0 and p.global_position.distance_to(state.flag_pos[f]) <= PICKUP_RANGE:
				if p.team == f and _dropped[f]:
					_return(f, p)
				elif p.team != f:
					_take(f, p)
		if p.carrying and p.global_position.distance_to(game.map.flags[p.team]) <= BASE_RANGE \
				and state.flag_carrier[p.team] == 0 and not _dropped[p.team]:
			_capture(p)


func on_kill(victim: Node, _killer: Node) -> void:
	if victim.carrying:
		_drop(1 - victim.team, victim.global_position)


func on_player_removed(player: Node) -> void:
	if player.carrying:
		_drop(1 - player.team, player.global_position)


func on_time_up() -> void:
	var s: PackedInt32Array = state.team_scores
	game.end_match(-2 if s[0] == s[1] else (0 if s[0] > s[1] else 1))


func _set_carrier(f: int, id: int) -> void:
	var a: PackedInt32Array = state.flag_carrier
	a[f] = id
	state.flag_carrier = a


func _set_flag_pos(f: int, pos: Vector2) -> void:
	var a: PackedVector2Array = state.flag_pos
	a[f] = pos
	state.flag_pos = a


func _take(f: int, p: Node) -> void:
	_dropped[f] = false
	_set_carrier(f, p.name.to_int())
	p.carrying = true
	game.announce("%s took the %s flag!" % [p.display_name(), game.team_name(f)], p.team)


func _drop(f: int, pos: Vector2) -> void:
	var c = game.get_player(state.flag_carrier[f])
	if c:
		c.carrying = false
	_set_carrier(f, 0)
	_set_flag_pos(f, pos.clamp(game.arena.position + Vector2(40, 40), game.arena.end - Vector2(40, 40)))
	_dropped[f] = true
	_return_left[f] = RETURN_TIME
	game.announce("The %s flag was dropped!" % game.team_name(f), 1 - f)


func _return(f: int, by: Node) -> void:
	_dropped[f] = false
	_set_flag_pos(f, game.map.flags[f])
	game.announce("The %s flag was returned%s" % [game.team_name(f), "" if by == null else " by " + by.display_name()], f)


func _capture(p: Node) -> void:
	var f: int = 1 - p.team
	p.carrying = false
	_set_carrier(f, 0)
	_set_flag_pos(f, game.map.flags[f])
	var s: PackedInt32Array = state.team_scores
	s[p.team] += 1
	state.team_scores = s
	game.announce("%s captured the %s flag!" % [p.display_name(), game.team_name(f)], p.team)
	if s[p.team] >= CAPTURE_LIMIT:
		game.end_match(p.team)
