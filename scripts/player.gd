extends CharacterBody2D
## Owner-authoritative movement/aim (replicated by MultiplayerSynchronizer);
## server-authoritative shooting and damage.

const SPEED := 300.0
const MAX_HEALTH := 100
const FIRE_COOLDOWN := 0.25

var aim_angle := 0.0
var health := MAX_HEALTH
var _last_shot := 0.0


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


func _process(_delta: float) -> void:
	queue_redraw()
	if is_multiplayer_authority() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		shoot.rpc_id(1, Vector2.from_angle(aim_angle))


@rpc("any_peer", "call_local", "reliable")
func shoot(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# Only the owner may shoot for this player (0 = local call on the host).
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != name.to_int():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot < FIRE_COOLDOWN or dir.length() < 0.5:
		return
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


func _draw() -> void:
	var color := Color.from_hsv(fmod(name.to_int() * 0.137, 1.0), 0.7, 1.0)
	draw_circle(Vector2.ZERO, 16, color)
	draw_line(Vector2.ZERO, Vector2.from_angle(aim_angle) * 26, Color.WHITE, 4)
	var w := 40.0
	draw_rect(Rect2(-w / 2, -30, w, 5), Color(0.2, 0, 0))
	draw_rect(Rect2(-w / 2, -30, w * clampf(float(health) / MAX_HEALTH, 0, 1), 5), Color.LIME)
