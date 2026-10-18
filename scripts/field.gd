extends Node2D
## Static farm-field backdrop, drawn procedurally. Seeded so every peer sees the same field.

var size := Vector2(1600, 900)
var theme_def := {"grass": Color("#6aa84f"), "path": true, "flora": 1.0}


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	draw_rect(Rect2(-200, -200, size.x + 400, size.y + 400), Color(theme_def.grass))
	for i in range(0, int(ceil(size.x / 100.0)), 2):
		draw_rect(Rect2(i * 100, 0, 100, size.y), Color(0, 0, 0, 0.045))

	var rng := RandomNumberGenerator.new()
	rng.seed = 20240607
	if theme_def.path:
		_draw_path()

	var area: float = size.x * size.y / (1600.0 * 900.0) * theme_def.flora
	for i in int(380 * area):
		var p := Vector2(rng.randf_range(10, size.x - 10), rng.randf_range(10, size.y - 10))
		var c := Color("#4f8a3a") if rng.randf() < 0.6 else Color("#7fbf5f")
		draw_line(p, p + Vector2(-3, -6), c, 1.5)
		draw_line(p, p + Vector2(0, -8), c, 1.5)
		draw_line(p, p + Vector2(3, -6), c, 1.5)

	var petals := [Color("#ffffff"), Color("#ffd93b"), Color("#ff7aa8"), Color("#b58cff"), Color("#ff8a3d")]
	for i in int(110 * area):
		var p := Vector2(rng.randf_range(20, size.x - 20), rng.randf_range(20, size.y - 20))
		var c: Color = petals[rng.randi() % petals.size()]
		for k in 5:
			draw_circle(p + Vector2.from_angle(k * TAU / 5) * 3.2, 2.4, c)
		draw_circle(p, 1.8, Color("#f5c518") if c != petals[1] else Color("#d2691e"))

	_draw_fence()


func _draw_path() -> void:
	var pts := [Vector2(-60, 800), Vector2(300, 730), Vector2(650, 620), Vector2(1000, 470),
		Vector2(1300, 430), Vector2(1660, 330)]
	var curve := Curve2D.new()
	for i in pts.size():
		var prev: Vector2 = pts[maxi(i - 1, 0)]
		var next: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var t := (next - prev) * 0.2
		curve.add_point(pts[i], -t, t)
	var line := curve.get_baked_points()
	draw_polyline(line, Color("#a9894f"), 96.0, true)
	draw_polyline(line, Color("#c4a46a"), 78.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 160:
		var p := line[rng.randi() % line.size()] + Vector2(rng.randf_range(-34, 34), rng.randf_range(-34, 34))
		draw_circle(p, rng.randf_range(1.0, 2.2), Color("#9c7d47") if i % 2 == 0 else Color("#d9bd86"))


func _draw_fence() -> void:
	var wood := Color("#8b5a2b")
	var post := Color("#6b4220")
	var inset := 10.0
	var r := Rect2(inset, inset, size.x - 2 * inset, size.y - 2 * inset)
	draw_rect(r, wood, false, 5.0)
	draw_rect(r.grow(-9), wood.lightened(0.15), false, 3.0)
	var x := r.position.x
	while x <= r.end.x:
		for y in [r.position.y, r.end.y]:
			draw_rect(Rect2(x - 5, y - 5, 10, 10), post)
			draw_rect(Rect2(x - 4, y - 4, 4, 4), post.lightened(0.3))
		x += 60.0
	var y2 := r.position.y
	while y2 <= r.end.y:
		for xx in [r.position.x, r.end.x]:
			draw_rect(Rect2(xx - 5, y2 - 5, 10, 10), post)
			draw_rect(Rect2(xx - 4, y2 - 4, 4, 4), post.lightened(0.3))
		y2 += 60.0
