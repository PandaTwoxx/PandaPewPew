extends "res://scripts/modes/game_mode.gd"
## Free-for-all: first to KILL_LIMIT wins, or the most kills when time runs out.

const KILL_LIMIT := 15


func _init() -> void:
	time_limit = 300.0


func on_kill(_victim: Node, killer: Node) -> void:
	if killer and killer.kills >= KILL_LIMIT:
		game.end_match(killer.name.to_int())


func on_time_up() -> void:
	var best := 0
	var best_kills := -1
	var tied := false
	for p in game.players_list():
		if p.kills > best_kills:
			best = p.name.to_int()
			best_kills = p.kills
			tied = false
		elif p.kills == best_kills:
			tied = true
	game.end_match(-2 if tied or best_kills <= 0 else best)
