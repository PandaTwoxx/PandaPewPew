extends Control
## Interactive animated Panda Mascot for PandaPewPew.
## Procedurally drawn with reactive eye tracking, natural blinking, and idle breathing.

var _pupil_offset: Vector2 = Vector2.ZERO
var _target_pupil: Vector2 = Vector2.ZERO
var _blink_timer: float = 3.0
var _blink_progress: float = 0.0 # 0.0 = open, 1.0 = fully closed
var _is_blinking: bool = false
var _wiggle_time: float = 0.0
var _hovered: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	# Calculate eye aim towards mouse cursor
	var center := size * 0.5
	var mouse_pos := get_local_mouse_position()
	var dir := mouse_pos - center
	var dist := dir.length()
	if dist > 1.0:
		var max_dist := 5.0
		_target_pupil = dir.normalized() * clampf(dist * 0.04, 0.0, max_dist)
	else:
		_target_pupil = Vector2.ZERO

	_pupil_offset = _pupil_offset.lerp(_target_pupil, delta * 12.0)

	# Blinking logic
	_blink_timer -= delta
	if _blink_timer <= 0.0 and not _is_blinking:
		_is_blinking = true
		_blink_progress = 0.0

	if _is_blinking:
		_blink_progress += delta * 14.0
		if _blink_progress >= PI:
			_is_blinking = false
			_blink_progress = 0.0
			_blink_timer = randf_range(2.5, 5.0)

	if _hovered:
		_wiggle_time += delta * 10.0
	else:
		_wiggle_time = move_toward(_wiggle_time, 0.0, delta * 4.0)

	queue_redraw()


func _on_mouse_entered() -> void:
	_hovered = true


func _on_mouse_exited() -> void:
	_hovered = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Trigger rapid blink and joyful ear wiggle on click!
		_is_blinking = true
		_blink_progress = 0.0
		_wiggle_time += 15.0


func _draw() -> void:
	var center := size * 0.5
	# Idle vertical breathing bob
	var bob := sin(Time.get_ticks_msec() * 0.0035) * 3.5
	center.y += bob

	var ear_wiggle := sin(_wiggle_time) * 3.0

	# 1. Ears (Left & Right)
	var left_ear_pos := center + Vector2(-34, -34 + ear_wiggle)
	var right_ear_pos := center + Vector2(34, -34 - ear_wiggle)
	var ear_color := Color(0.12, 0.14, 0.18)
	var inner_ear_color := Color(0.95, 0.65, 0.75)

	draw_circle(left_ear_pos, 19, ear_color)
	draw_circle(right_ear_pos, 19, ear_color)
	draw_circle(left_ear_pos, 10, inner_ear_color)
	draw_circle(right_ear_pos, 10, inner_ear_color)

	# 2. Main Head
	var head_color := Color(0.98, 0.98, 0.99)
	var head_outline := Color(0.12, 0.14, 0.18)
	# Soft outer shadow
	draw_circle(center + Vector2(0, 3), 48, Color(0, 0, 0, 0.25))
	draw_circle(center, 47, head_outline)
	draw_circle(center, 45, head_color)

	# 3. Tactical Headband (Bamboo Green with neon edge & gold badge)
	var headband_rect := Rect2(center.x - 42, center.y - 28, 84, 12)
	draw_rect(headband_rect, Color(0.08, 0.6, 0.35), true)
	draw_line(Vector2(center.x - 42, center.y - 28), Vector2(center.x + 42, center.y - 28), Color(0.35, 0.98, 0.6), 2.0)
	draw_line(Vector2(center.x - 42, center.y - 16), Vector2(center.x + 42, center.y - 16), Color(0.04, 0.45, 0.25), 1.5)
	# Center star/badge on headband
	draw_circle(Vector2(center.x, center.y - 22), 4.5, Color(1.0, 0.88, 0.2))
	draw_circle(Vector2(center.x, center.y - 22), 2.0, Color(1.0, 1.0, 0.6))

	# 4. Cheeks (Cute blushing glow)
	var blush_color := Color(1.0, 0.45, 0.6, 0.38)
	draw_circle(center + Vector2(-30, 15), 9, blush_color)
	draw_circle(center + Vector2(30, 15), 9, blush_color)

	# 5. Eye Patches (Angled dark ovals)
	var left_patch_center := center + Vector2(-19, -4)
	var right_patch_center := center + Vector2(19, -4)
	_draw_rotated_ellipse(left_patch_center, 14, 18, deg_to_rad(-16), ear_color)
	_draw_rotated_ellipse(right_patch_center, 14, 18, deg_to_rad(16), ear_color)

	# 6. Eyes & Pupils
	var blink_amount := sin(_blink_progress) if _is_blinking else 0.0

	var left_eye_pos := left_patch_center + Vector2(1, 0)
	var right_eye_pos := right_patch_center + Vector2(-1, 0)

	if blink_amount > 0.7:
		# Drawn closed eye curved arc
		_draw_curved_eye_closed(left_eye_pos, 9)
		_draw_curved_eye_closed(right_eye_pos, 9)
	else:
		var eye_h := 8.0 * (1.0 - blink_amount)
		# Sclera (White eye backing)
		_draw_rotated_ellipse(left_eye_pos, 7.5, eye_h, 0.0, Color.WHITE)
		_draw_rotated_ellipse(right_eye_pos, 7.5, eye_h, 0.0, Color.WHITE)

		# Pupil (Shiny dark pupil tracking mouse)
		var p_left := left_eye_pos + _pupil_offset
		var p_right := right_eye_pos + _pupil_offset
		draw_circle(p_left, 4.5, Color(0.08, 0.1, 0.15))
		draw_circle(p_right, 4.5, Color(0.08, 0.1, 0.15))

		# Glint / Specular shine
		draw_circle(p_left + Vector2(-1.5, -1.5), 1.8, Color.WHITE)
		draw_circle(p_right + Vector2(-1.5, -1.5), 1.8, Color.WHITE)
		draw_circle(p_left + Vector2(1.5, 1.2), 0.9, Color(1, 1, 1, 0.8))
		draw_circle(p_right + Vector2(1.5, 1.2), 0.9, Color(1, 1, 1, 0.8))

	# 7. Snout / Nose
	var nose_pos := center + Vector2(0, 11)
	draw_colored_polygon([
		nose_pos + Vector2(-6, -3),
		nose_pos + Vector2(6, -3),
		nose_pos + Vector2(0, 4)
	], ear_color)

	# 8. Cute Cheerful Mouth (:3 shape)
	var mouth_color := Color(0.18, 0.2, 0.25)
	draw_line(nose_pos + Vector2(0, 3), nose_pos + Vector2(0, 7), mouth_color, 2.0)
	draw_line(nose_pos + Vector2(0, 7), nose_pos + Vector2(-5, 6), mouth_color, 2.0)
	draw_line(nose_pos + Vector2(-5, 6), nose_pos + Vector2(-8, 3), mouth_color, 2.0)
	draw_line(nose_pos + Vector2(0, 7), nose_pos + Vector2(5, 6), mouth_color, 2.0)
	draw_line(nose_pos + Vector2(5, 6), nose_pos + Vector2(8, 3), mouth_color, 2.0)


func _draw_rotated_ellipse(pos: Vector2, rx: float, ry: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segs := 18
	for i in range(segs):
		var th := float(i) / float(segs) * TAU
		var p := Vector2(cos(th) * rx, sin(th) * ry).rotated(angle)
		points.append(pos + p)
	draw_colored_polygon(points, color)


func _draw_curved_eye_closed(pos: Vector2, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(7):
		var frac := float(i) / 6.0
		var x := lerpf(-width, width, frac)
		var y := (1.0 - pow(frac * 2.0 - 1.0, 2)) * 3.5
		pts.append(pos + Vector2(x, y))
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(0.95, 0.95, 0.98), 2.5)
