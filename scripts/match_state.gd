extends Node
## Server-authoritative match state, replicated to every peer that has joined the game scene.
## Packed arrays are always reassigned whole so ON_CHANGE replication notices the update.

const PLAYING := 0
const ENDED := 1

var phase := PLAYING
var time_left := 0           ## whole seconds
var winner := -1             ## -1 none, -2 draw; a team index or a peer id depending on the mode
var team_scores := PackedInt32Array([0, 0])
var flag_pos := PackedVector2Array()    ## CTF: where each team's flag rests (unused while carried)
var flag_carrier := PackedInt32Array()  ## CTF: peer id carrying each team's flag, 0 = nobody
var cp_owner := PackedInt32Array()      ## Conquest: owning team per point, -1 = neutral
var cp_prog := PackedFloat32Array()     ## Conquest: signed capture progress per point

var sync: MultiplayerSynchronizer


func _ready() -> void:
	var cfg := SceneReplicationConfig.new()
	for prop in ["phase", "time_left", "winner", "team_scores", "flag_pos", "flag_carrier", "cp_owner", "cp_prog"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync = MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	add_child(sync)
