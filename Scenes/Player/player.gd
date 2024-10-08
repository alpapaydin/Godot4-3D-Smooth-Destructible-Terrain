extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 4.0
var defaultSpeed = 4.0
var sprintSpeed = 25.0
var jump_speed = 11.0
var mouse_sensitivity = 0.002
var actionPressed = false
var actionCooldown = 0.05
var altActionCooldown = 0.05
var actionTimer = 0.0
var altActionTimer = 0.0

@onready var raycast := $Camera3D/RayCast3D
@onready var world := $/root/main/map

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_input():
	var input = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = movement_dir.x * speed
	velocity.z = movement_dir.z * speed

func _physics_process(delta):
	actionTimer -= delta
	altActionTimer -= delta

	doAction()
	doAltAction()
	velocity.y += -gravity * delta
	get_input()
	move_and_slide()

func _unhandled_input(event):
	if event.is_action_pressed("action"):
		$AnimationPlayer.play("swing")
		actionPressed = true
	if event.is_action_released("action"):
		$AnimationPlayer.stop()
		actionPressed = false
	if event.is_action_pressed("sprint"):
		speed = sprintSpeed
	if event.is_action_released("sprint"):
		speed = defaultSpeed
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		%Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
		%Camera3D.rotation.x = clampf(%Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
	if event.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_speed

func breakBlocks(isDigging: bool):
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is StaticBody3D:
			var collisionPoint = raycast.get_collision_point()
			var particleScene := preload("res://Scenes/Player/mining_particles.tscn")
			var particles := particleScene.instantiate()
			particles.position = collisionPoint
			world.add_child(particles)
			particles.emitting = true
			world.dig(collisionPoint, 1, isDigging)
		
func doAction():
	if actionPressed and actionTimer <= 0:
		breakBlocks(true)
		actionTimer = actionCooldown

func doAltAction():
	if Input.is_action_pressed("alt_action") and altActionTimer <= 0:
		breakBlocks(false)
		altActionTimer = altActionCooldown
		
