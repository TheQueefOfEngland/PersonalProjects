extends CharacterBody3D

@onready var anim = $AnimationPlayer
@onready var r_hand = $playerHUD/SubViewportContainer/SubViewport/PlayerCam/Hands/RHand
var default_r_hand_pos : Vector3 = Vector3(0.584, -0.311, -0.596)
@onready var l_hand = $playerHUD/SubViewportContainer/SubViewport/PlayerCam/Hands/Lhand

#player stats, editable from scene
@export var STATS = {
	'MaxHealth' : 100,
	'MaxMana' : 100,
	'MaxStamina' : 100,
	'WalkSpeed' : 16.2,
	'SprintSpeed' : 21.5,
	'JumpVelocity' : 7.0,
}

var sprinting : bool

@export var primary_weapon : PackedScene
@export var secondary_weapon : PackedScene
@export var starter_weapon : PackedScene
var current_weapon 
var next_weapon

var max_health = STATS.MaxHealth
var max_mana = STATS.MaxMana
var max_stamina = STATS.MaxStamina
var current_health : float
var current_mana : float
var current_stamina : float
var damage

var mouse_input : Vector2




func _ready():
	add_to_group('Player')
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	current_weapon = starter_weapon
	
	current_health = 55
	current_mana = max_mana
	
	if starter_weapon != null:
		equip_starter_weapon()
		
	
	
	if TheDirector.in_hq:
		$playerHUD.visible = false
	else:
		$playerHUD.visible = true
	pass

#////////////

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	
	player_movement(delta)
#////////////
#	look_around()
	
	TheDirector.players_current_position = global_transform.origin
	
	if current_health != max_health:
		stat_regen()
		return
	
	
	if Input.is_action_pressed("RMB"): #<---messes with the ads
		r_hand.rotation.x = 0
		r_hand.rotation.y = 0
		r_hand.rotation.z = 0
	pass

func _process(delta):
	#/player stat bars
	update_player_HUD()
	
	damage = TheDirector.player_damage
	
	var called_death : bool
	if current_health <= 0 and not called_death:
		death_bro()
		called_death = true
	
	if next_weapon != current_weapon:
		current_weapon = next_weapon
	
	get_current_weapon()
	pass


func _input(event):
	
	if Input.is_action_just_pressed("ui_end"):
		print(str(TheDirector.DEATHSTATS, TheDirector.kills_this_game))
	
	
	if event is InputEventMouseMotion:
		get_mouse_input(event)
		look_around(event)
	
	if Input.is_action_just_pressed('SpellCast'):
		current_mana -= 25
	
	if Input.is_action_just_pressed("ThrowFlare"):
		throw_flare()
	
	if Input.is_action_just_pressed('LMB'):
		attack(damage)
		pass
	
	if Input.is_action_just_pressed("Flashlight"):
		toggle_flashlight()
	
	pass

func get_mouse_input(event):
	#/mouse Input for looking around
	var playerview = $playerHUD/SubViewportContainer/SubViewport/PlayerCam
	var world_view = $WorldCam
	var mouseSensitivity : float = 0.5 
	
	#/rotates the players head and body
	rotate_y(deg_to_rad(-event.relative.x * mouseSensitivity))
	world_view.rotate_x(deg_to_rad(-event.relative.y * mouseSensitivity))
	
	
	
	pass

func look_around(event):
	var world_view = $WorldCam
	var playerview = $playerHUD/SubViewportContainer/SubViewport/PlayerCam
	#clamps world view
	world_view.rotation.x = clamp(world_view.rotation.x, deg_to_rad(-89), deg_to_rad(84.95))
	world_view.rotation.y = clamp(world_view.rotation.y, deg_to_rad(-89), deg_to_rad(84.95))
	
	#clamps the HUD
	playerview.rotation.x = clamp(playerview.rotation.x, deg_to_rad(-89), deg_to_rad(84.95))
	playerview.rotation.y = clamp(playerview.rotation.y, deg_to_rad(-89), deg_to_rad(84.95))
	mouse_input = event.relative
	pass


func player_movement(delta):
	#/movement
	var walkspeed = STATS.WalkSpeed
	var sprintspeed = STATS.SprintSpeed
	var jumpheight = STATS.JumpVelocity
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		TheDirector.DEATHSTATS.total_air_time += 0.01

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jumpheight

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector('ui_left', 'ui_right', 'ui_up', 'ui_down')
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprint_speed = walkspeed + 15
	var sprinting : bool
	
	if Input.is_action_pressed("Sprint"):
		sprinting = true
	else:
		sprinting = false
	
	if direction and not sprinting:
		velocity.x = direction.x * walkspeed
		velocity.z = direction.z * walkspeed
	elif direction and sprinting:
		velocity.x = direction.x * sprintspeed
		velocity.z = direction.z * sprint_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walkspeed)
		velocity.z = move_toward(velocity.z, 0, walkspeed)
	
	move_and_slide()
	
	#camera tilting functions
	cam_tilt(input_dir.x, delta)
	weapon_tilt(input_dir.x, delta)
	weapon_sway(delta)
	weapon_bob(velocity.length(),delta)
	
	pass

func update_player_HUD():
	var hp_bar = $playerHUD/AspectRatioContainer/Container2/StatBars/HPBar
	var mp_bar = $playerHUD/AspectRatioContainer/Container2/StatBars/MpBar
	var stat_bars = $playerHUD/AspectRatioContainer/Container2/StatBars
	var mag_label = $playerHUD/AspectRatioContainer/Container2/Labels/MagLabel
	
	hp_bar.value = current_health
	mp_bar.value = current_mana
	
	mag_label.text = str(TheDirector.current_mag, ' / ', TheDirector.max_mag)
	$playerHUD/AspectRatioContainer/Container2/Labels/AmmoLabel.text = str(TheDirector.current_pool)
	if current_health == max_health and current_mana == max_mana:
		stat_bars.visible = false
	else:
		stat_bars.visible = true
	
	
	if TheDirector.current_flares == TheDirector.max_flares:
		$playerHUD/AspectRatioContainer/Container2/Labels/Recharging.visible = true
	else:
		$playerHUD/AspectRatioContainer/Container2/Labels/Recharging.visible = false
		
	
	$playerHUD/AspectRatioContainer/Container2/Labels/CurrentWallet.text = str(TheDirector.current_wallet)
	
	
	pass


func stat_regen():
	if current_health != max_health:
		await (get_tree().create_timer(2.0).timeout)
		current_health = move_toward(current_health, max_health, 0.05)
		
	elif current_mana != max_mana:
		await (get_tree().create_timer(2.0).timeout)
		print('regenerating mana')
		current_mana = move_toward(current_mana, max_mana, 0.2)
		
	else:
		current_health = current_health
		current_mana = current_mana
	
	return 


func throw_flare():
	var flare_path = preload("res://ASSETS/Toys/glow_flare.tscn")
	var flare = flare_path.instantiate()
	var throw_strength = 15
	var angle = global_rotation.y
	
	if TheDirector.current_flares != TheDirector.max_flares:
		get_parent().add_child(flare)
		TheDirector.current_flares += 1
		
		flare.global_transform.origin = global_transform.origin
		flare.rotation_degrees = rotation_degrees
		flare.apply_central_impulse(global_transform.basis.y * (throw_strength))
		flare.apply_central_impulse(-global_transform.basis.z * throw_strength) 
	
	pass


func equip_starter_weapon():
	var weapon_path = starter_weapon
	var weapon = weapon_path.instantiate()
	var pool_hud = $playerHUD/AspectRatioContainer/Container2/Labels/AmmoLabel
	
	
	r_hand.add_child(weapon)
	weapon.transform.origin = r_hand.transform.origin
	weapon.connect('player_attack', attack)
	pool_hud.text = str(TheDirector.current_pool)
#	anim.play_backwards("equip_weapon")
	pass

func equip_spell():
	#same as equip weapon and weapon functions but relace with a hand that does something
	
	pass

func attack(damage):
	var target = $WorldCam/HitCast.get_collider()
	var blood_fx = preload("res://ASSETS/Toys/blood_fx.tscn")
	var dust_fx = preload("res://ASSETS/Toys/berm_fx.tscn")
	var berm = dust_fx.instantiate()
	var blood = blood_fx.instantiate()
	
	if target != null: #/keeps from missing a shot to crash the game
#		print(str(target, ' / ', damage))
		if target.is_in_group("Enemy") and target.has_method("hurt"):
			target.hurt(damage)
			get_tree().get_root().add_child(blood)
			blood.transform.origin  = $WorldCam/HitCast.get_collision_point()
#			
		else:
			get_tree().get_root().add_child(berm)
			berm.transform.origin  = $WorldCam/HitCast.get_collision_point()
			
	pass


@export var flashlight_battery = 45.5

func toggle_flashlight():
	var flashlight = $WorldCam/Flashlight
	
	if flashlight.visible == true:
		flashlight.visible = false
	elif flashlight.visible == false:
		flashlight.visible = true

func player_hurt(damage):
	current_health -= damage
	$BloodFx.restart()
	pass


func death_bro():
	var player_cam = $playerHUD/SubViewportContainer/SubViewport/PlayerCam
	var death_cam = $DeathCam
	var death_hang_time = 5.0
	
	player_cam.current = false
	death_cam.current = true
	
	$MeshInstance3D.rotation.x = 90.0
	
	await (get_tree().create_timer(death_hang_time).timeout)
	TheDirector.DEATHSTATS.total_deaths += 1
	get_tree().change_scene_to_file("res://LEVELS/hq.tscn")
	pass


func get_current_weapon():
	if Input.is_action_just_pressed("Primary_Equip"):
		next_weapon = primary_weapon
		if next_weapon != null:
			switch_weapon()
	if Input.is_action_just_pressed("Secondary_Equip"):
		next_weapon = secondary_weapon
		if next_weapon != null:
			switch_weapon()
	if Input.is_action_just_pressed('Starter_Equip'):
		next_weapon = starter_weapon
		if next_weapon != null:
			switch_weapon()
	
	
	pass


func switch_weapon():
	var weapon_path = next_weapon
	var weapon = weapon_path.instantiate()
	
	#/body
	get_tree().call_group('Weapon', 'switch_weapon')
	await (get_tree().create_timer(.6).timeout)
	r_hand.add_child(weapon)
	weapon.transform.origin = r_hand.position
#	r_hand.rotation.y = 0
	pass


#//cam juice

@export var speed = 5.0
@onready var cam = $WorldCam
@export var cam_speed : float = 5
@export var cam_rotation_amount : float = .1

@onready var weapon_holder = r_hand
@export var weapon_sway_amount : float = 0.05
@export var weapon_rotation_amount : float = 0.05
@export var invert_weapon_sway : bool = false


var def_weapon_holder_pos : Vector3


func cam_tilt(input_x, delta):
	if cam:
		cam.rotation.z = lerp(cam.rotation.z, -input_x * cam_rotation_amount, 10 * delta)

func weapon_tilt(input_x, delta):
	if weapon_holder:
		weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, -input_x * weapon_rotation_amount * 10, 10 * delta)

func weapon_sway(delta):
	mouse_input = lerp(mouse_input,Vector2.ZERO,10*delta)
	weapon_holder.rotation.x = lerp(weapon_holder.rotation.x, mouse_input.y * weapon_rotation_amount * (-1 if invert_weapon_sway else 1), 10 * delta)
	weapon_holder.rotation.y = lerp(weapon_holder.rotation.y, mouse_input.x * weapon_rotation_amount * (-1 if invert_weapon_sway else 1), 10 * delta)	

#
func weapon_bob(vel : float, delta):
	if weapon_holder:
		if vel > 0 and is_on_floor():
			var bob_amount : float = 0.03
			var bob_freq : float = 0.01
			weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount, 10 * delta)
			weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount, 10 * delta)
			
		else:
			weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y, 10 * delta)
			weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x, 10 * delta)
