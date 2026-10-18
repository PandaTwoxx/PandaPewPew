extends RefCounted
## Base class for server-side mode rules. Modes only ever run on the server: they mutate the
## replicated MatchState and the players' server-owned fields, and call game.end_match().

var game: Node
var state: Node
var time_limit := 300.0  ## seconds per match


## Called at the start of every match (also after a restart).
func setup() -> void:
	pass


## Called every physics frame while the match is running.
func tick(_delta: float) -> void:
	pass


## victim has just died; killer is null for suicides/disconnected shooters.
func on_kill(_victim: Node, _killer: Node) -> void:
	pass


## A player is about to be removed (disconnect).
func on_player_removed(_player: Node) -> void:
	pass


func on_time_up() -> void:
	game.end_match(-2)
