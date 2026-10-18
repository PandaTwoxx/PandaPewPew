extends "res://scripts/modes/game_mode.gd"
## Teams fight over control points. Each owned point gives its team 1 score per second.
## cp_prog is signed capture progress: -1 = team 0 fully capturing, +1 = team 1. Ownership is sticky
## and only flips when progress reaches +-1.

const SCORE_LIMIT := 200
const CAPTURE_TIME := 6.0  ## seconds for one player to capture from neutral
const MAX_CAPTURERS := 3   ## extra players beyond this don't speed it up

var _accum := 0.0


func _init() -> void:
	time_limit = 480.0


func setup() -> void:
	_accum = 0.0
	var n: int = game.map.points.size()
	var owners := PackedInt32Array()
	owners.resize(n)
	owners.fill(-1)
	var prog := PackedFloat32Array()
	prog.resize(n)
	state.cp_owner = owners
	state.cp_prog = prog
	state.team_scores = PackedInt32Array([0, 0])


func tick(delta: float) -> void:
	var owners: PackedInt32Array = state.cp_owner
	var prog: PackedFloat32Array = state.cp_prog
	var players: Array = game.players_list()
	for i in owners.size():
		var present := [0, 0]
		for p in players:
			if p.alive and p.team >= 0 and p.global_position.distance_to(game.map.points[i]) <= game.MapDefs.POINT_RADIUS:
				present[p.team] += 1
		if present[0] > 0 and present[1] > 0:
			continue  # contested
		if present[0] == 0 and present[1] == 0:
			prog[i] = move_toward(prog[i], 0.0, delta / CAPTURE_TIME * 0.5)
			continue
		var t := 0 if present[0] > 0 else 1
		var rate := delta / CAPTURE_TIME * minf(present[t], MAX_CAPTURERS)
		if owners[i] == t:
			prog[i] = move_toward(prog[i], 0.0, rate)
		else:
			prog[i] = move_toward(prog[i], -1.0 if t == 0 else 1.0, rate)
			if absf(prog[i]) >= 1.0:
				owners[i] = t
				prog[i] = 0.0
				game.announce("%s captured point %s!" % [game.team_name(t), game.MapDefs.POINT_NAMES[i]], t)
	state.cp_owner = owners
	state.cp_prog = prog

	_accum += delta
	if _accum >= 1.0:
		_accum -= 1.0
		var s: PackedInt32Array = state.team_scores
		for o in owners:
			if o >= 0:
				s[o] += 1
		state.team_scores = s
		for t in 2:
			if s[t] >= SCORE_LIMIT:
				game.end_match(t)
				return


func on_time_up() -> void:
	var s: PackedInt32Array = state.team_scores
	game.end_match(-2 if s[0] == s[1] else (0 if s[0] > s[1] else 1))
