extends Area2D
## Farm-produce projectile. Simulated on all peers for visuals;
## the server alone resolves hits and despawns it.

const SPEED := 700.0
const DAMAGE := 20
const LIFETIME := 2.0
const SPLAT_COLORS := [Color("#d9302c"), Color("#7ec850"), Color("#f2c230"), Color("#fff3cf")]

var direction := Vector2.RIGHT
var shooter := 0
var _t := 0.0


func _ready() -> void:
	z_index = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6
	shape.shape = circle
	add_child(shape)
	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _exit_tree() -> void:
	var game := get_parent().get_parent() if get_parent() else null
	if game and game.has_method("splat"):
		game.splat.call_deferred(global_position, SPLAT_COLORS[shooter % 4])


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_t += delta
	queue_redraw()


func _draw() -> void:
	var kind := shooter % 4
	for i in 3:
		draw_circle(-direction * (6 + i * 6), 4.0 - i, Color(1, 1, 1, 0.22 - i * 0.06))
	var spin := _t * 14.0
	match kind:
		0: # tomato
			draw_circle(Vector2.ZERO, 7, Color("#d9302c"))
			draw_circle(Vector2(-2, -2), 2.2, Color(1, 1, 1, 0.6))
			for k in 5:
				draw_circle(Vector2.from_angle(spin + k * TAU / 5) * 3.5, 1.6, Color("#3d8c3a"))
		1: # cabbage
			draw_circle(Vector2.ZERO, 7, Color("#7ec850"))
			draw_arc(Vector2.ZERO, 4.5, spin, spin + 3.8, 10, Color("#b9e68f"), 1.8)
			draw_arc(Vector2.ZERO, 2.2, spin + 2.0, spin + 5.5, 8, Color("#4f9a38"), 1.6)
		2: # corn
			draw_set_transform(Vector2.ZERO, direction.angle(), Vector2(1.7, 1.0))
			draw_circle(Vector2.ZERO, 5, Color("#f2c230"))
			draw_set_transform(Vector2.ZERO, direction.angle())
			for k in 3:
				draw_circle(Vector2(-4 + k * 4, 0), 1.3, Color("#c99a1a"))
			draw_set_transform(Vector2.ZERO, 0)
		3: # egg
			draw_set_transform(Vector2.ZERO, direction.angle(), Vector2(1.3, 1.0))
			draw_circle(Vector2.ZERO, 5.5, Color("#fff3cf"))
			draw_circle(Vector2(-1, -1.5), 1.6, Color(1, 1, 1, 0.8))
			draw_set_transform(Vector2.ZERO, 0)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		# The game decides: shooter and teammates are passed through, everyone else absorbs the bullet.
		if not get_parent().get_parent().hit_player(body, shooter, DAMAGE):
			return
	queue_free()
