extends RefCounted
## Game mode registry plus the team palette shared by the HUD, players and objectives.

const TEAM_COLORS := [Color("#e0452e"), Color("#3b82f6")]
const TEAM_NAMES := ["RED", "BLUE"]

const ORDER := ["kills", "ctf", "conquest"]
const MODES := {
	"kills": {
		"name": "Kill Count",
		"teams": false,
		"script": preload("res://scripts/modes/kill_count.gd"),
		"desc": "Free-for-all. First to 15 kills wins.",
	},
	"ctf": {
		"name": "Capture the Flag",
		"teams": true,
		"script": preload("res://scripts/modes/ctf.gd"),
		"desc": "Steal the enemy flag and bring it to your base. First to 3 captures wins.",
	},
	"conquest": {
		"name": "Conquest",
		"teams": true,
		"script": preload("res://scripts/modes/conquest.gd"),
		"desc": "Hold control points to earn score. First team to 200 wins.",
	},
}


static func has_mode(id: String) -> bool:
	return MODES.has(id)


static func uses_teams(id: String) -> bool:
	return MODES.get(id, MODES.kills).teams


static func create(id: String, game: Node) -> RefCounted:
	var m = MODES[id].script.new()
	m.game = game
	m.state = game.state
	return m


static func team_color(team: int) -> Color:
	return TEAM_COLORS[team] if team >= 0 and team < TEAM_COLORS.size() else Color.WHITE
