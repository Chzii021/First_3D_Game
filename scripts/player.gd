# Adapted from the Silver Demon Studios 3D Platformer Starter Kit controller.
# Its movement, double-jump and Idle/Run/Jump/Flip states are retained.
@tool

extends CharacterBody3D

signal fell

@export var move_speed := 7.0
@export var jump_force := 10.0
@export var double_jump_force := 9.0

var controls_enabled := true
var can_double_jump := true
var model: Node3D
var animation: AnimationPlayer
var last_state := ""

func _ready() -> void:
	add_to_group("Player")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 0.99
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.52
	add_child(collider)
	model = load("res://assets/astronaut.glb").instantiate()
	model.name = "PolyPizzaAstronaut"
	model.scale = Vector3.ONE * 0.87
	add_child(model)
	animation = _find_animation_player(model)
	_play("Idle")

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if controls_enabled:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.z -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.z += 1.0
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 25.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 25.0 * delta)
	if is_on_floor():
		can_double_jump = true
		if controls_enabled and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)) and not _jump_held:
			velocity.y = jump_force
			_play("Jump", true)
	else:
		velocity.y -= 24.0 * delta
		if controls_enabled and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)) and not _jump_held and can_double_jump:
			velocity.y = double_jump_force
			can_double_jump = false
			_play("Jump", true)
			var flip := create_tween()
			flip.tween_property(model, "rotation:x", TAU, 0.45)
			flip.tween_callback(func(): model.rotation.x = 0.0)
	_jump_held = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	move_and_slide()
	if direction.length() > 0.01:
		# The Poly Pizza astronaut faces +Z in its source model.
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
	if is_on_floor():
		if direction.length() > 0.01:
			_play("Run")
		else:
			_play("Idle")
	if global_position.y < -12.0:
		fell.emit()

var _jump_held := false

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play(state: String, restart := false) -> void:
	if animation == null or (last_state == state and not restart):
		return
	for name in animation.get_animation_list():
		if str(name).ends_with("|" + state):
			if restart:
				animation.stop()
			animation.play(name, 0.18)
			last_state = state
			return
