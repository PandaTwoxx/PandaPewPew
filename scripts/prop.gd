extends StaticBody2D
## A solid farm obstacle (hay, fence, barn, pond, tree) with a collider and procedural art.

var kind := ""
var size := Vector2.ZERO


func setup(k: String, rect: Rect2) -> void:
	kind = k
	size = rect.size
	position = rect.get_center()
	z_index = -5


func _ready() -> void:
	var shape := CollisionShape2D.new()
	if kind == "pond" or kind == "tree":
		var c := CircleShape2D.new()
		c.radius = size.x / 2.0 * (0.95 if kind == "pond" else 0.8)
		shape.shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = size
		shape.shape = r
	add_child(shape)


func _draw() -> void:
	match kind:
		"hay": _draw_hay()
		"fence": _draw_fence()
		"barn": _draw_barn()
		"pond": _draw_pond()
		"tree": _draw_tree()


func _along(horizontal: bool, a: float, b: float) -> Vector2:
	return Vector2(a, b) if horizontal else Vector2(b, a)


func _draw_hay() -> void:
	var horizontal := size.x >= size.y
	var r := minf(size.x, size.y) / 2.0
	var n := int(round(maxf(size.x, size.y) / (r * 2.0)))
	for i in n:
		var c := _along(horizontal, (i - (n - 1) / 2.0) * 2.0 * r, 0.0)
		draw_circle(c + Vector2(3, 5), r, Color(0, 0, 0, 0.25))
		draw_circle(c, r, Color("#dcb84e"))
		draw_arc(c, r * 0.72, 0, TAU, 28, Color("#bf9a35"), 1.6)
		draw_arc(c, r * 0.45, 0, TAU, 24, Color("#bf9a35"), 1.6)
		draw_arc(c, r * 0.2, 0, TAU, 16, Color("#bf9a35"), 1.6)
		draw_arc(c, r - 1, 0, TAU, 32, Color("#a07a22"), 2.5)
		draw_arc(c, r * 0.85, PI * 1.1, PI * 1.6, 10, Color("#f3dc8a"), 2.0)


func _draw_fence() -> void:
	var horizontal := size.x >= size.y
	var length := maxf(size.x, size.y)
	draw_rect(Rect2(-size / 2 + Vector2(3, 4), size), Color(0, 0, 0, 0.2))
	for off in [-3.5, 3.5]:
		var a := _along(horizontal, -length / 2, off - 1.5)
		var sz := Vector2(length, 3) if horizontal else Vector2(3, length)
		draw_rect(Rect2(a, sz), Color("#a0693a"))
	var x := -length / 2 + 8.0
	while x <= length / 2:
		var c := _along(horizontal, x, 0.0)
		draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("#6b4220"))
		draw_rect(Rect2(c - Vector2(4, 4), Vector2(4, 4)), Color("#9c6a3c"))
		x += 40.0


func _draw_barn() -> void:
	var r := Rect2(-size / 2, size)
	draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.28))
	draw_rect(r, Color("#a8322d"))
	var x := r.position.x + 14.0
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("#8a2824"), 2.0)
		x += 14.0
	draw_rect(Rect2(r.position.x, -7, r.size.x, 14), Color("#c9453f"))
	draw_rect(Rect2(r.position.x, -7, r.size.x, 3), Color("#e06b63"))
	draw_rect(r, Color("#f2ede0"), false, 5.0)
	draw_rect(Rect2(-24, r.end.y - 38, 48, 28), Color("#5b1d1a"))
	draw_line(Vector2(-24, r.end.y - 38), Vector2(24, r.end.y - 10), Color("#f2ede0"), 3.0)
	draw_line(Vector2(24, r.end.y - 38), Vector2(-24, r.end.y - 10), Color("#f2ede0"), 3.0)
	draw_circle(Vector2(r.size.x * 0.28, 0), 6, Color("#333333"))
	draw_line(Vector2(r.size.x * 0.28 - 12, 0), Vector2(r.size.x * 0.28 + 12, 0), Color("#333333"), 2.0)
	draw_line(Vector2(r.size.x * 0.28, -12), Vector2(r.size.x * 0.28, 12), Color("#333333"), 2.0)


func _draw_pond() -> void:
	var r := size.x / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7 + position.y)
	draw_circle(Vector2.ZERO, r + 10, Color("#d8c48a"))
	draw_circle(Vector2.ZERO, r + 3, Color("#5f8f4a"))
	draw_circle(Vector2.ZERO, r, Color("#2f6fa8"))
	draw_circle(Vector2.ZERO, r * 0.82, Color("#3d86c4"))
	draw_circle(Vector2(-r * 0.1, -r * 0.1), r * 0.5, Color(0.5, 0.75, 0.95, 0.35))
	draw_arc(Vector2(-r * 0.25, -r * 0.25), r * 0.45, PI * 1.05, PI * 1.55, 12, Color(1, 1, 1, 0.55), 2.5)
	for i in 4:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r * 0.15, r * 0.6)
		draw_circle(p, 9, Color("#3f8f3a"))
		draw_line(p, p + Vector2.from_angle(rng.randf() * TAU) * 9, Color("#3d86c4"), 2.5)
		if i % 2 == 0:
			draw_circle(p, 3.5, Color("#ff9ec4"))
			draw_circle(p, 1.5, Color("#ffe066"))
	for i in 7:
		var a := rng.randf() * TAU
		var base := Vector2.from_angle(a) * (r + 2)
		var tip := base + Vector2.from_angle(a + rng.randf_range(-0.4, 0.4)) * 14
		draw_line(base, tip, Color("#3d7a2e"), 2.0)
		draw_circle(tip, 2.5, Color("#6b4220"))


func _draw_tree() -> void:
	var r := size.x / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 13 + position.y)
	draw_circle(Vector2(8, 10), r, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, r, Color("#2e6b2e"))
	draw_circle(Vector2(-3, -3), r * 0.85, Color("#3d8c3a"))
	draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.5, Color("#55a84a"))
	for i in 8:
		var p := Vector2.from_angle(i * TAU / 8) * r * 0.75
		draw_circle(p, r * 0.22, Color("#35803a"))
	for i in 6:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0, r * 0.7)
		draw_circle(p, 3.2, Color("#d9302c"))
		draw_circle(p + Vector2(-1, -1), 1.0, Color(1, 1, 1, 0.7))
