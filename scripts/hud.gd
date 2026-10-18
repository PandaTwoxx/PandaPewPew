extends CanvasLayer
## Match HUD: timer and scores, objective hint, kill/event feed, respawn and result banners,
## and a hold-Tab scoreboard. Everything is read from the replicated state, so all peers match.

const ModeDefs := preload("res://scripts/mode_defs.gd")
const MapDefs := preload("res://scripts/map_defs.gd")
const FEED_TIME := 5.0
const FEED_MAX := 6

var game: Node

var _canvas: Control
var _font: Font
var _feed: Array = []  # [text, color, expires_at]
var _last_phase := 0
var _ended_at := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func push_feed(text: String, color: Color) -> void:
	_feed.append([text, color, _now() + FEED_TIME])
	if _feed.size() > FEED_MAX:
		_feed.pop_front()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if game.state.phase != _last_phase:
		_last_phase = game.state.phase
		_ended_at = _now()
	_canvas.queue_redraw()


func _text(pos: Vector2, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_canvas.draw_string_outline(_font, pos, text, align, width, size, 5, Color("#2b1d0e"))
	_canvas.draw_string(_font, pos, text, align, width, size, color)


func _draw_hud() -> void:
	var vp := _canvas.size
	if game.map.is_empty():
		_text(Vector2(0, vp.y / 2), "Connecting...", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		return
	_draw_top(vp)
	_draw_feed(vp)
	_draw_help()
	if game.state.phase == game.state.ENDED:
		_draw_result(vp)
	else:
		_draw_respawn(vp)
	if Input.is_key_pressed(KEY_TAB) or game.state.phase == game.state.ENDED:
		_draw_scoreboard(vp)


func _draw_top(vp: Vector2) -> void:
	var s = game.state
	var cx := vp.x / 2
	var secs: int = s.time_left
	_text(Vector2(cx - 60, 30), "%d:%02d" % [secs / 60, secs % 60], 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120)
	var info: Dictionary = ModeDefs.MODES[game.mode_id]
	_text(Vector2(cx - 150, 50), "%s - %s" % [info.name, game.map.name], 13, Color("#f2e6c9"),
		HORIZONTAL_ALIGNMENT_CENTER, 300)
	if info.teams:
		_text(Vector2(cx - 150, 34), str(s.team_scores[0]), 30, ModeDefs.team_color(0), HORIZONTAL_ALIGNMENT_RIGHT, 80)
		_text(Vector2(cx + 70, 34), str(s.team_scores[1]), 30, ModeDefs.team_color(1), HORIZONTAL_ALIGNMENT_LEFT, 80)
		var me = game.local_player()
		if me and me.team >= 0:
			_text(Vector2(cx - 150, 70), "You are on the %s team" % game.team_name(me.team), 13,
				ModeDefs.team_color(me.team), HORIZONTAL_ALIGNMENT_CENTER, 300)
	else:
		var me = game.local_player()
		var best = null
		for p in game.players_list():
			if best == null or p.kills > best.kills:
				best = p
		var line := "Kills: %d" % (me.kills if me else 0)
		if best:
			line += "   Leader: %s (%d)" % [best.display_name(), best.kills]
		_text(Vector2(cx - 200, 70), line, 13, Color("#f2e6c9"), HORIZONTAL_ALIGNMENT_CENTER, 400)


func _draw_feed(vp: Vector2) -> void:
	var now := _now()
	_feed = _feed.filter(func(e): return e[2] > now)
	var y := 28.0
	for e in _feed:
		_text(Vector2(vp.x - 480, y), e[0], 14, e[1], HORIZONTAL_ALIGNMENT_RIGHT, 470)
		y += 20.0


func _draw_help() -> void:
	var info: Dictionary = ModeDefs.MODES[game.mode_id]
	_text(Vector2(10, 22), "WASD move, mouse aim, click shoot, Tab scoreboard, Esc leave" + (
		"  [dedicated server]" if Net.dedicated else ""), 13, Color("#f2e6c9"))
	_text(Vector2(10, 40), info.desc, 12, Color("#cfe3b8"))


func _draw_respawn(vp: Vector2) -> void:
	var me = game.local_player()
	if me == null or me.alive:
		return
	var left := maxf(game.RESPAWN_DELAY - (_now() - me.died_at), 0.0)
	_text(Vector2(0, vp.y * 0.62), "You were eliminated", 28, Color("#ffb347"), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	_text(Vector2(0, vp.y * 0.62 + 34), "Respawning in %d" % ceili(left), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_result(vp: Vector2) -> void:
	var s = game.state
	var text := "DRAW"
	var col := Color.WHITE
	if s.winner >= 0:
		if ModeDefs.uses_teams(game.mode_id):
			text = "%s TEAM WINS!" % game.team_name(s.winner)
			col = ModeDefs.team_color(s.winner)
		else:
			var w = game.get_player(s.winner)
			text = "%s WINS!" % (w.display_name() if w else "Winner")
			col = Color("#ffd93b")
	_text(Vector2(0, vp.y * 0.2), text, 44, col, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	var left := maxf(game.END_DELAY - (_now() - _ended_at), 0.0)
	_text(Vector2(0, vp.y * 0.2 + 34), "Next match in %d" % ceili(left), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_scoreboard(vp: Vector2) -> void:
	var rows: Array = game.players_list()
	rows.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	var w := 420.0
	var h := 40.0 + rows.size() * 24.0
	var x := (vp.x - w) / 2
	var y := vp.y * 0.3
	_canvas.draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
	_text(Vector2(x + 14, y + 26), "Player", 14, Color("#f2e6c9"))
	_text(Vector2(x + w - 150, y + 26), "Kills", 14, Color("#f2e6c9"), HORIZONTAL_ALIGNMENT_RIGHT, 60)
	_text(Vector2(x + w - 80, y + 26), "Deaths", 14, Color("#f2e6c9"), HORIZONTAL_ALIGNMENT_RIGHT, 66)
	var i := 0
	for p in rows:
		var ry := y + 50 + i * 24.0
		var col: Color = ModeDefs.team_color(p.team) if p.team >= 0 else Color.WHITE
		var label: String = p.display_name() + (" (you)" if p.is_multiplayer_authority() else "")
		_text(Vector2(x + 14, ry), label, 14, col)
		_text(Vector2(x + w - 150, ry), str(p.kills), 14, col, HORIZONTAL_ALIGNMENT_RIGHT, 60)
		_text(Vector2(x + w - 80, ry), str(p.deaths), 14, col, HORIZONTAL_ALIGNMENT_RIGHT, 66)
		i += 1
