extends Control
## Atmospheric animated background for PandaPewPew.
## Renders floating bamboo leaves, glowing energy particles, and a tactical cyber-grid.

class BambooLeaf:
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var rot_speed: float
	var scale: float
	var sway_phase: float
	var color: Color

class SparkParticle:
	var pos: Vector2
	var vel: Vector2
	var radius: float
	var alpha: float
	var pulse_speed: float
	var phase: float

var _leaves: Array[BambooLeaf] = []
var _sparks: Array[SparkParticle] = []
var _scanline_y: float = 0.0


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Initialize leaves
	for i in range(24):
		var leaf := BambooLeaf.new()
		leaf.pos = Vector2(randf_range(0, 1200), randf_range(0, 700))
		leaf.vel = Vector2(randf_range(-15, 15), randf_range(25, 60))
		leaf.rot = randf_range(0, TAU)
		leaf.rot_speed = randf_range(-1.2, 1.2)
		leaf.scale = randf_range(0.7, 1.3)
		leaf.sway_phase = randf_range(0, TAU)
		var g := randf_range(0.5, 0.85)
		leaf.color = Color(0.12, g, 0.35, randf_range(0.25, 0.55))
		_leaves.append(leaf)

	# Initialize energy sparks
	for i in range(40):
		var spark := SparkParticle.new()
		spark.pos = Vector2(randf_range(0, 1200), randf_range(0, 700))
		spark.vel = Vector2(randf_range(-8, 8), randf_range(-30, -70))
		spark.radius = randf_range(1.5, 3.5)
		spark.pulse_speed = randf_range(2.0, 5.0)
		spark.phase = randf_range(0, TAU)
		_sparks.append(spark)


func _process(delta: float) -> void:
	var w := size.x if size.x > 0 else 1152.0
	var h := size.y if size.y > 0 else 648.0
	var time := Time.get_ticks_msec() / 1000.0

	# Update leaves
	for leaf in _leaves:
		leaf.pos.y += leaf.vel.y * delta
		leaf.pos.x += (leaf.vel.x + sin(time * 1.5 + leaf.sway_phase) * 20.0) * delta
		leaf.rot += leaf.rot_speed * delta

		# Wrap around screen edges
		if leaf.pos.y > h + 30.0:
			leaf.pos.y = -30.0
			leaf.pos.x = randf_range(0, w)
		if leaf.pos.x < -30.0:
			leaf.pos.x = w + 30.0
		elif leaf.pos.x > w + 30.0:
			leaf.pos.x = -30.0

	# Update sparks
	for spark in _sparks:
		spark.pos += spark.vel * delta
		spark.phase += spark.pulse_speed * delta
		spark.alpha = (sin(spark.phase) * 0.5 + 0.5) * 0.6 + 0.15

		if spark.pos.y < -20.0:
			spark.pos.y = h + 20.0
			spark.pos.x = randf_range(0, w)
		if spark.pos.x < -20.0:
			spark.pos.x = w + 20.0
		elif spark.pos.x > w + 20.0:
			spark.pos.x = -20.0

	# Scanline sweep
	_scanline_y += delta * 40.0
	if _scanline_y > h:
		_scanline_y = 0.0

	queue_redraw()


func _draw() -> void:
	var w := size.x if size.x > 0 else 1152.0
	var h := size.y if size.y > 0 else 648.0

	# 1. Dark Cyber Bamboo Forest Backdrop
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.07, 0.10))

	# 2. Atmospheric vignette / radial gradient
	var center := Vector2(w * 0.5, h * 0.45)
	for r in range(4):
		var rad := 300.0 + r * 150.0
		var col := Color(0.08, 0.22, 0.18, 0.05 * (4 - r))
		draw_circle(center, rad, col)

	# 3. Subtle Cybernetic Grid
	var grid_step := 64.0
	var grid_col := Color(0.12, 0.35, 0.28, 0.12)
	var x := 0.0
	while x <= w:
		draw_line(Vector2(x, 0), Vector2(x, h), grid_col, 1.0)
		x += grid_step
	var y := 0.0
	while y <= h:
		draw_line(Vector2(0, y), Vector2(w, y), grid_col, 1.0)
		y += grid_step

	# 4. Drifting Bamboo Leaves
	for leaf in _leaves:
		_draw_bamboo_leaf(leaf)

	# 5. Glowing Energy Sparks
	for spark in _sparks:
		var col := Color(0.3, 0.95, 0.7, spark.alpha)
		draw_circle(spark.pos, spark.radius, col)
		draw_circle(spark.pos, spark.radius * 2.2, Color(0.3, 0.95, 0.7, spark.alpha * 0.25))

	# 6. Subtle laser scanning line
	draw_line(Vector2(0, _scanline_y), Vector2(w, _scanline_y), Color(0.2, 0.9, 0.5, 0.06), 2.0)


func _draw_bamboo_leaf(leaf: BambooLeaf) -> void:
	# Classic pointed bamboo leaf polygon
	var s := leaf.scale * 14.0
	var points := PackedVector2Array([
		Vector2(0, -s * 1.6),
		Vector2(s * 0.45, -s * 0.5),
		Vector2(s * 0.55, s * 0.6),
		Vector2(0, s * 1.5),
		Vector2(-s * 0.55, s * 0.6),
		Vector2(-s * 0.45, -s * 0.5)
	])

	# Rotate & translate
	for i in range(points.size()):
		points[i] = leaf.pos + points[i].rotated(leaf.rot)

	draw_colored_polygon(points, leaf.color)
	# Central leaf vein
	var p_top := leaf.pos + Vector2(0, -s * 1.4).rotated(leaf.rot)
	var p_bot := leaf.pos + Vector2(0, s * 1.3).rotated(leaf.rot)
	var vein_col := Color(leaf.color.r, leaf.color.g, leaf.color.b, leaf.color.a * 0.7)
	draw_line(p_top, p_bot, vein_col, 1.2)
