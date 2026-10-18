extends Node2D
## Short-lived splatter burst where a projectile lands.

var color := Color.WHITE
var _blobs: Array[Vector3] = []


func _ready() -> void:
	z_index = 2
	for i in 9:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(4, 16)
		_blobs.append(Vector3(d.x, d.y, randf_range(1.5, 4.0)))
	rotation = randf() * TAU
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.5)
	t.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6, color)
	for b in _blobs:
		draw_circle(Vector2(b.x, b.y), b.z, color)
