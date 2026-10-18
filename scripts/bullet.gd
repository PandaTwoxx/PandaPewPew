extends Area2D
## Simulated on all peers for visuals; the server alone resolves hits and despawns it.

const SPEED := 700.0
const DAMAGE := 20
const LIFETIME := 2.0

var direction := Vector2.RIGHT
var shooter := 0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4
	shape.shape = circle
	add_child(shape)
	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
		get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4, Color.YELLOW)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		if body.name.to_int() == shooter:
			return
		body.take_damage.rpc(DAMAGE)
	queue_free()
