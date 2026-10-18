extends CharacterBody2D
## Owner-authoritative movement/aim (replicated by MultiplayerSynchronizer);
## server-authoritative shooting and damage.

const SPEED := 300.0
const MAX_HEALTH := 100
const FIRE_COOLDOWN := 0.25
const ROUND_TIME := 10.0     # seconds the gun may fire once a round starts
const GUN_COOLDOWN := 5.0    # seconds it is locked after the round ends

var aim_angle := 0.0
var health := MAX_HEALTH
var _last_shot := 0.0
var _round_start := -1.0  # when the current firing round began (-1 = none); server + owner track it


func _enter_tree() -> void:
	# Node name is the owning peer id (set by the spawn function).
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	if is_multiplayer_authority() and not Net.dedicated:
		var cam := Camera2D.new()
		add_child(cam)
		cam.make_current()
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = 1600
		cam.limit_bottom = 900


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED
	move_and_slide()
	aim_angle = (get_global_mouse_position() - global_position).angle()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## 0 = ready (no round running), 1 = firing round, 2 = cooling down.
func _gun_phase() -> int:
	if _round_start < 0.0:
		return 0
	var el := _now() - _round_start
	if el < ROUND_TIME:
		return 1
	if el < ROUND_TIME + GUN_COOLDOWN:
		return 2
	_round_start = -1.0
	return 0


func _process(_delta: float) -> void:
	queue_redraw()
	if is_multiplayer_authority() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and _gun_phase() != 2:
		shoot.rpc_id(1, Vector2.from_angle(aim_angle))


@rpc("any_peer", "reliable")
func _round_started() -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_round_start = _now()


@rpc("any_peer", "call_local", "reliable")
func shoot(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# Only the owner may shoot for this player (0 = local call on the host).
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != name.to_int():
		return
	var now := _now()
	if now - _last_shot < FIRE_COOLDOWN or dir.length() < 0.5:
		return
	var phase := _gun_phase()
	if phase == 2:
		return
	if phase == 0:
		_round_start = now
		if name.to_int() != 1:
			_round_started.rpc_id(name.to_int())
	_last_shot = now
	get_parent().get_parent().spawn_bullet(
		global_position + dir.normalized() * 24, dir.normalized(), name.to_int())


## Called by the server (via rpc) on every peer to apply damage.
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	health -= amount
	if health <= 0:
		health = MAX_HEALTH
		if is_multiplayer_authority():
			position = get_parent().get_parent().random_spawn_point()


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(c, aim_angle, Vector2(rx, ry))
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, aim_angle)


func _eyes(x: float, spread: float, r: float) -> void:
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(x, spread * s), r, Color.BLACK)
		draw_circle(Vector2(x + 0.6, spread * s - 0.6), r * 0.35, Color.WHITE)


func _draw() -> void:
	var species := name.to_int() % 4
	draw_set_transform(Vector2.ZERO, 0)
	draw_circle(Vector2(3, 6), 17, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, aim_angle)
	match species:
		0: _draw_pig()
		1: _draw_cow()
		2: _draw_sheep()
		3: _draw_chicken()
	draw_set_transform(Vector2.ZERO, 0)
	var w := 40.0
	draw_rect(Rect2(-w / 2 - 1, -33, w + 2, 7), Color(0, 0, 0, 0.6))
	var frac := clampf(float(health) / MAX_HEALTH, 0, 1)
	var hc := Color("#5fd35f") if frac > 0.5 else (Color("#f2c230") if frac > 0.25 else Color("#e0452e"))
	draw_rect(Rect2(-w / 2, -32, w * frac, 5), hc)
	if is_multiplayer_authority() and not Net.dedicated:
		var phase := _gun_phase()
		var el := _now() - _round_start
		var gf := 1.0
		var gc := Color("#7fd0ff")
		if phase == 1:
			gf = 1.0 - el / ROUND_TIME
			gc = Color("#ffb347")
		elif phase == 2:
			gf = (el - ROUND_TIME) / GUN_COOLDOWN
			gc = Color("#e0452e")
		draw_rect(Rect2(-w / 2 - 1, 25, w + 2, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, 26, w * clampf(gf, 0, 1), 4), gc)


func _gun() -> void:
	# Veggie blaster: wooden barrel with a brass muzzle, pointing along the aim.
	# The owner sees it glow red while locked out.
	var hot := is_multiplayer_authority() and _gun_phase() == 2
	draw_line(Vector2(6, 0), Vector2(30, 0), Color("#7a2a1e") if hot else Color("#5b3a1e"), 7)
	draw_line(Vector2(6, -1.5), Vector2(30, -1.5), Color("#c0452e") if hot else Color("#8a5a2e"), 2)
	draw_line(Vector2(27, 0), Vector2(31, 0), Color("#555555") if hot else Color("#d4a017"), 8)


func _draw_pig() -> void:
	var pink := Color("#f4a6b8")
	var dark := Color("#e2849c")
	draw_circle(Vector2(-18, 0), 3.5, dark)
	_ellipse(Vector2.ZERO, 17, 15, pink)
	_gun()
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(4, 10 * s), 4.5, dark)
	draw_circle(Vector2(10, 0), 11, pink)
	_ellipse(Vector2(19, 0), 5, 6, Color("#f08aa3"))
	draw_circle(Vector2(19.5, -2), 1.2, Color("#8a3a52"))
	draw_circle(Vector2(19.5, 2), 1.2, Color("#8a3a52"))
	_eyes(12, 5.5, 2.0)


func _draw_cow() -> void:
	var white := Color("#f6f3ee")
	_ellipse(Vector2.ZERO, 18, 15, white)
	draw_circle(Vector2(-6, -7), 5, Color("#2a2a2a"))
	draw_circle(Vector2(-10, 6), 4.5, Color("#2a2a2a"))
	draw_circle(Vector2(2, 9), 3.5, Color("#2a2a2a"))
	draw_line(Vector2(-18, 0), Vector2(-24, 4), Color("#2a2a2a"), 2)
	_gun()
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(5, 13 * s), 3, Color("#efe2b0"))
		draw_circle(Vector2(8, 11 * s), 4.5, white.darkened(0.05))
	draw_circle(Vector2(10, 0), 11, white)
	draw_circle(Vector2(13, -5), 4.5, Color("#2a2a2a"))
	_ellipse(Vector2(19, 0), 5.5, 6.5, Color("#f2b8b0"))
	draw_circle(Vector2(19.5, -2.2), 1.2, Color("#a85a58"))
	draw_circle(Vector2(19.5, 2.2), 1.2, Color("#a85a58"))
	_eyes(13, 5.5, 2.0)


func _draw_sheep() -> void:
	var wool := Color("#f1efe6")
	var shade := Color("#d9d5c6")
	draw_circle(Vector2.ZERO, 15, shade)
	for i in 9:
		draw_circle(Vector2.from_angle(i * TAU / 9) * 11, 8, wool)
	draw_circle(Vector2.ZERO, 12, wool)
	_gun()
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(8, 9 * s), 3.5, Color("#3c3c3c"))
	draw_circle(Vector2(12, 0), 8.5, Color("#3c3c3c"))
	draw_circle(Vector2(8, 0), 5, wool)
	_eyes(14, 4.0, 1.8)
	draw_circle(Vector2(18, 0), 1.6, Color("#222222"))


func _draw_chicken() -> void:
	var white := Color("#fffaf0")
	for k in 3:
		draw_circle(Vector2(-17 - k * 1.5, (k - 1) * 6.0), 5, Color("#d9d2c0") if k != 1 else Color("#c9c0aa"))
	_ellipse(Vector2.ZERO, 15, 13, white)
	for s in [-1.0, 1.0]:
		_ellipse(Vector2(-3, 10 * s), 9, 5, Color("#e6dcc4"))
	_gun()
	draw_circle(Vector2(11, 0), 8.5, white)
	_ellipse(Vector2(10, 0), 5, 3, Color("#e0302c"))
	draw_colored_polygon(PackedVector2Array([Vector2(18, -3.5), Vector2(18, 3.5), Vector2(25, 0)]), Color("#ff9a1f"))
	_eyes(14, 5, 1.8)
