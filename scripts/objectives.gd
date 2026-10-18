extends Node2D
## Draws mode objectives (CTF bases/flags, Conquest points) from the replicated MatchState.
## Two instances: "ground" sits under the players, "air" (flags) over them.

const ModeDefs := preload("res://scripts/mode_defs.gd")
const MapDefs := preload("res://scripts/map_defs.gd")

var game: Node
var layer := "ground"


func _ready() -> void:
	z_index = -4 if layer == "ground" else 3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game.map.is_empty():
		return
	match game.mode_id:
		"ctf":
			if layer == "ground":
				_draw_bases()
			else:
				_draw_flags()
		"conquest":
			if layer == "ground":
				_draw_points()


func _draw_bases() -> void:
	for t in 2:
		var c: Vector2 = game.map.flags[t]
		var col := ModeDefs.team_color(t)
		draw_circle(c, 55, Color(col, 0.18))
		draw_arc(c, 55, 0, TAU, 40, Color(col, 0.7), 3.0)


func _draw_flags() -> void:
	var s = game.state
	if s.flag_pos.size() != 2:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for f in 2:
		if s.flag_carrier[f] != 0:
			continue  # the carrier draws it
		var p: Vector2 = s.flag_pos[f]
		var away := p.distance_to(game.map.flags[f]) > 4.0
		if away:
			p.y += sin(t * 5.0) * 3.0
		draw_flag(self, p, ModeDefs.team_color(f), 1.0)


## Shared with the player so a carried flag looks the same as a planted one.
static func draw_flag(ci: CanvasItem, base: Vector2, col: Color, scale: float) -> void:
	ci.draw_line(base, base + Vector2(0, -34) * scale, Color("#4a3320"), 3.0 * scale)
	ci.draw_colored_polygon(PackedVector2Array([
		base + Vector2(1, -34) * scale, base + Vector2(24, -27) * scale, base + Vector2(1, -19) * scale]), col)
	ci.draw_circle(base, 4.0 * scale, Color("#4a3320"))


func _draw_points() -> void:
	var s = game.state
	var font := ThemeDB.fallback_font
	for i in game.map.points.size():
		var c: Vector2 = game.map.points[i]
		var owner_team: int = s.cp_owner[i] if i < s.cp_owner.size() else -1
		var prog: float = s.cp_prog[i] if i < s.cp_prog.size() else 0.0
		var base_col := ModeDefs.team_color(owner_team) if owner_team >= 0 else Color(0.85, 0.85, 0.85)
		draw_circle(c, MapDefs.POINT_RADIUS, Color(base_col, 0.2))
		draw_arc(c, MapDefs.POINT_RADIUS, 0, TAU, 48, Color(base_col, 0.85), 3.0)
		if absf(prog) > 0.001:
			var cap_col := ModeDefs.team_color(0 if prog < 0 else 1)
			draw_arc(c, MapDefs.POINT_RADIUS - 8, -PI / 2, -PI / 2 + TAU * absf(prog), 48, cap_col, 6.0)
		draw_string(font, c + Vector2(-20, 11), MapDefs.POINT_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, 40, 32,
			Color(1, 1, 1, 0.85))
