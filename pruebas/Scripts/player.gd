extends CharacterBody2D

signal cambio_vida(nueva_vida)
signal juego_terminado

# #########################################################
# 1. ESTADOS Y CONFIGURACIÓN
# #########################################################
enum Estado { IDLE, MOVIENDO, SALTANDO, CAYENDO, ATACANDO, BARRIDO, PARED, GROUND_POUND, ATURDIDO, MUERTO }

#MOVILIDAD BÁSICA HORIZONTAL
@export_group("Movimiento Horizontal")
const VEL_NORMAL        = 135.0
const VEL_CORRER        = 200.0
const VEL_BARRIDO       = 350.0 

#MOVILIDAD BÁSICA VERTICAL
@export_group("Salto y Gravedad")
const FUERZA_SALTO       = -300.0
const FUERZA_SALTO_SUPER = -380.0
const GRAVEDAD           = 980.0
const MULT_CORTE_SALTO   = 0.5
const TIEMPO_COYOTE      = 0.12
const TIEMPO_BUFFER_SALTO = 0.1

#MOVIMIENTOS ESPECIALES
@export_group("Especiales")
const VEL_GROUND_POUND      = 200.0 
const VEL_DESLIZAMIENTO     = 50.0
const REBOTE_PARED_X        = 220.0
const TIEMPO_BLOQUEO_WALLJUMP = 0.5 
const PAUSA_ANTICIPACION     = 0.3 
const VENTANA_SALTO_POTENTE  = 0.2 
const TIEMPO_MAX_BARRIDO     = 0.3
const TIEMPO_MAX_ATURDIDO    = 0.3 

#SISTEMA VIDA
@export_group("Combate y Vida")
@export var limite_caida_y : int = 200 
@export var vida_maxima : int = 800
@export var vida_actual : int = 800

# =========================================================
# 2. VARIABLES INTERNAS DE ESTADO
# =========================================================

# --- Control Principal ---
var estado_actual      : Estado = Estado.IDLE
var posicion_inicio    : Vector2 
var mask_original      : int
var esperando_reinicio : bool = false 
var dir_accion         : float = 0.0 

# --- Entradas (Inputs) ---
var input_dir   : float = 0.0
var input_corre : bool  = false

# --- Temporizadores de Físicas ---
var timer_super_salto  : float = 0.0
var timer_ground_pound : float = 0.0
var timer_wall_jump    : float = 0.0 
var coyote_timer       : float = 0.0
var jump_buffer_timer  : float = 0.0

# --- Temporizadores de Habilidades ---
var tiempo_barrido_actual  : float = 0.0   
var tiempo_aturdido_actual : float = 0.0

# --- Banderas Condicionales (Flags) ---
var es_salto_potenciado : bool = false
var bloqueo_barrido     : bool = false 
var recuperando_gp      : bool = false    
var es_invulnerable     : bool = false

@onready var animaciones = $AnimatedSprite2D
@onready var hitbox_ataque = $HitboxAtaque/CollisionShape2D

# #########################################################
# 3. BUCLE PRINCIPAL
# #########################################################
func _ready():
	posicion_inicio = global_position
	mask_original = collision_mask
	await get_tree().process_frame
	cambio_vida.emit(vida_actual)

func _physics_process(delta: float) -> void:
	if esperando_reinicio:
		if Input.is_key_pressed(KEY_Z):
			get_tree().reload_current_scene()
		return  
	
	if global_position.y > limite_caida_y and estado_actual != Estado.MUERTO:
		morir()
		
	if estado_actual == Estado.MUERTO:
		velocity.y += GRAVEDAD * delta
		move_and_slide()
		return
		
	if is_on_floor() and Input.is_action_just_pressed("ui_down"):
		position.y += 2

	leer_inputs()
	actualizar_timers(delta)
	procesar_gravedad(delta)
	
	if is_on_floor():
		coyote_timer = TIEMPO_COYOTE
		timer_wall_jump = 0 
		
		if estado_actual != Estado.BARRIDO and not (Input.is_action_pressed("Ataque") and input_corre):
			bloqueo_barrido = false
	
	match estado_actual:
		Estado.IDLE:          logica_idle(delta)
		Estado.MOVIENDO:      logica_movimiento(delta)
		Estado.SALTANDO, \
		Estado.CAYENDO:       logica_aire(delta)
		Estado.ATACANDO:      pass 
		Estado.BARRIDO:       logica_barrido(delta)
		Estado.PARED:         logica_pared() 
		Estado.GROUND_POUND:  logica_ground_pound(delta)
		Estado.ATURDIDO:      logica_aturdido(delta)

	move_and_slide() 
	
	for i in get_slide_collision_count():
		var choque = get_slide_collision(i).get_collider()
		
		if choque and choque.is_in_group("enemigo"):
			var a_salvo = false
			
			if es_invulnerable: a_salvo = true 
			if estado_actual == Estado.BARRIDO: a_salvo = true 
			
			if not a_salvo and estado_actual != Estado.MUERTO:
				print("player muerto")
				morir()
				break
	# =========================================================
	
	verificar_inputs_especiales()

	var todas_las_balas = get_tree().get_nodes_in_group("bala")
	for bala in todas_las_balas:
		if global_position.distance_to(bala.global_position) < 5.0:
			var a_salvo = false
			if es_invulnerable: a_salvo = true 
			if estado_actual == Estado.BARRIDO: a_salvo = true 
			
			if not a_salvo and estado_actual != Estado.MUERTO:
				print("impacto de bala")
				bala.queue_free()
				morir()
				break

func leer_inputs() -> void:
	if estado_actual == Estado.MUERTO: 
		input_dir = 0
		input_corre = false
		return

	var raw_dir = Input.get_axis("ui_left", "ui_right")
	input_dir = raw_dir if abs(raw_dir) > 0.15 else 0.0
	input_corre = Input.is_action_pressed("Correr")
	if Input.is_action_just_pressed("Saltar"):
		jump_buffer_timer = TIEMPO_BUFFER_SALTO

func actualizar_timers(delta: float) -> void:
	if timer_super_salto > 0: timer_super_salto -= delta
	if coyote_timer > 0:      coyote_timer -= delta
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if timer_wall_jump > 0:   timer_wall_jump -= delta

func procesar_gravedad(delta):
	if not is_on_floor() and estado_actual != Estado.PARED:
		if estado_actual == Estado.GROUND_POUND: 
			return
		else: 
			velocity.y += GRAVEDAD * delta

func cambiar_estado(nuevo: Estado, forzar: bool = false) -> void:
	if estado_actual == nuevo: return
	
	var es_accion = estado_actual in [Estado.ATACANDO, Estado.BARRIDO, Estado.GROUND_POUND, Estado.ATURDIDO, Estado.MUERTO]
	if es_accion and not forzar: return
	
	animaciones.speed_scale = 1.0
	hitbox_ataque.disabled = true 
	
	if estado_actual == Estado.BARRIDO:
		set_collision_mask_value(3, true)
		
	estado_actual = nuevo
	
	match estado_actual:
		Estado.BARRIDO:
			tiempo_barrido_actual = 0.0
			dir_accion = -1 if animaciones.flip_h else 1
			hitbox_ataque.disabled = false 
			animaciones.play("Barrido") 
		Estado.ATURDIDO:
			tiempo_aturdido_actual = 0.0
			hitbox_ataque.disabled = true
			velocity.x = -dir_accion * 200 
			velocity.y = -150 
			animaciones.play("IDLE") 
			animaciones.modulate = Color(0.77, 0.065, 0.278, 1.0) 
		Estado.GROUND_POUND:
			timer_ground_pound = PAUSA_ANTICIPACION
			recuperando_gp = false 
			velocity = Vector2.ZERO 
			animaciones.play("Bomba") 
		Estado.SALTANDO:
			ejecutar_salto()
		Estado.ATACANDO:  
			iniciar_accion("Ataque")

func verificar_inputs_especiales() -> void:
	if timer_wall_jump > 0: return

	if estado_actual == Estado.GROUND_POUND:
		if recuperando_gp: return

	var es_libre = estado_actual in [Estado.IDLE, Estado.MOVIENDO, Estado.SALTANDO, Estado.CAYENDO]
	if not es_libre: return

	if jump_buffer_timer > 0 and coyote_timer > 0:
		cambiar_estado(Estado.SALTANDO)
		return

	if is_on_floor() and input_corre and Input.is_action_just_pressed("Ataque") and not bloqueo_barrido:
		cambiar_estado(Estado.BARRIDO)
		return

	if Input.is_action_just_pressed("Ataque"):
		if not is_on_floor(): 
			cambiar_estado(Estado.GROUND_POUND)
		else: 
			cambiar_estado(Estado.ATACANDO)

func ejecutar_salto() -> void:
	if timer_wall_jump > 0:
		velocity.y = FUERZA_SALTO 
		return

	var salto_final = FUERZA_SALTO
	if timer_super_salto > 0:
		salto_final = FUERZA_SALTO_SUPER
		es_salto_potenciado = true
		timer_super_salto = 0
	else:
		es_salto_potenciado = false

	velocity.y = salto_final
	coyote_timer = 0
	jump_buffer_timer = 0

@warning_ignore("unused_parameter")
func logica_idle(delta: float):
	velocity.x = 0 
	animaciones.play("IDLE")
	if input_dir != 0: 
		animaciones.flip_h = (input_dir < 0)
		cambiar_estado(Estado.MOVIENDO)

@warning_ignore("unused_parameter")
func logica_movimiento(delta: float) -> void:
	var v_objetivo = VEL_CORRER if input_corre else VEL_NORMAL
	animaciones.speed_scale = 1.5 if input_corre else 1.0
	
	velocity.x = input_dir * v_objetivo
	
	animaciones.play("Caminado")
	if input_dir != 0: animaciones.flip_h = (input_dir < 0)
	
	if input_dir == 0: cambiar_estado(Estado.IDLE)
	elif not is_on_floor() and coyote_timer <= 0: cambiar_estado(Estado.CAYENDO)

@warning_ignore("unused_parameter")
func logica_aire(delta: float) -> void:
	if timer_wall_jump > 0:
		animaciones.play("Saltar") 
		animaciones.flip_h = (velocity.x < 0)
	else:
		var v_objetivo = VEL_CORRER if input_corre else VEL_NORMAL
		velocity.x = input_dir * v_objetivo
		
		if input_dir != 0:
			animaciones.flip_h = (input_dir < 0)
			
		if velocity.y < 0:
			animaciones.play("Saltar")
		else:
			animaciones.play("Caida")
	
	if not es_salto_potenciado and Input.is_action_just_released("Saltar") and velocity.y < -50:
		velocity.y *= MULT_CORTE_SALTO
	
	if is_on_floor():
		es_salto_potenciado = false
		cambiar_estado(Estado.IDLE if input_dir == 0 else Estado.MOVIENDO, true)
	elif is_on_wall_only() and velocity.y > 0:
		var n = get_wall_normal()
		if (n.x < 0 and input_dir > 0) or (n.x > 0 and input_dir < 0): 
			cambiar_estado(Estado.PARED, true)

func logica_barrido(delta: float) -> void:
	velocity.x = dir_accion * VEL_BARRIDO
	tiempo_barrido_actual += delta
	
	if is_on_wall():
		cambiar_estado(Estado.ATURDIDO, true)
		return
		
	if tiempo_barrido_actual >= TIEMPO_MAX_BARRIDO:
		hitbox_ataque.disabled = true
		bloqueo_barrido = true
		cambiar_estado(Estado.MOVIENDO if input_dir != 0 else Estado.IDLE, true)

func logica_aturdido(delta: float) -> void:
	tiempo_aturdido_actual += delta
	if is_on_floor() and tiempo_aturdido_actual >= TIEMPO_MAX_ATURDIDO:
		animaciones.modulate = Color.WHITE
		cambiar_estado(Estado.IDLE, true)

func logica_pared():
	var n = get_wall_normal()
	var presionando_hacia_pared = (n.x < 0 and input_dir > 0) or (n.x > 0 and input_dir < 0)
	
	if not presionando_hacia_pared or not is_on_wall() or is_on_floor():
		cambiar_estado(Estado.CAYENDO, true)
		return
	
	velocity.y = min(velocity.y, VEL_DESLIZAMIENTO)
	animaciones.play("Pared")
	if n.x != 0: animaciones.flip_h = (n.x > 0)
	
	if jump_buffer_timer > 0:
		velocity.x = n.x * REBOTE_PARED_X
		timer_wall_jump = TIEMPO_BLOQUEO_WALLJUMP
		animaciones.flip_h = (velocity.x < 0)
		cambiar_estado(Estado.SALTANDO, true)

func logica_ground_pound(delta: float) -> void:
	if animaciones.animation == "Bomba" and animaciones.frame >= 3:
		animaciones.pause()
		animaciones.frame = 3

	if recuperando_gp:
		if not is_on_floor():
			recuperando_gp = false
			hitbox_ataque.disabled = false
			return
		velocity = Vector2.ZERO
		return

	if timer_ground_pound > 0:
		timer_ground_pound -= delta
		velocity = Vector2.ZERO
		return

	velocity.x = 0
	velocity.y = VEL_GROUND_POUND
	hitbox_ataque.disabled = false 
	
	if is_on_floor():
		recuperando_gp = true
		hitbox_ataque.disabled = true 
		await get_tree().create_timer(0.2).timeout
		if estado_actual == Estado.GROUND_POUND and recuperando_gp:
			recuperando_gp = false
			timer_super_salto = VENTANA_SALTO_POTENTE
			cambiar_estado(Estado.IDLE, true)

func iniciar_accion(anim: String) -> void:
	animaciones.play(anim)
	hitbox_ataque.disabled = false 
	if not animaciones.animation_finished.is_connected(_on_anim_finished):
		animaciones.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)

func recibir_daño(cantidad: int = 1, origen_daño_x: float = 0.0, es_proyectil: bool = false):
	if es_invulnerable or estado_actual == Estado.MUERTO: return
	if estado_actual == Estado.BARRIDO and not es_proyectil: return
	morir()
			
func morir():
	if estado_actual == Estado.MUERTO: return
	
	cambiar_estado(Estado.MUERTO, true)
	vida_actual -= 1
	cambio_vida.emit(vida_actual)
	
	velocity = Vector2.ZERO
	if animaciones.sprite_frames.has_animation("Muerte"): animaciones.play("Muerte")
	else: animaciones.stop()
	
	await get_tree().create_timer(1.0).timeout
	if vida_actual > 0: respawn()
	else: game_over_total()

func respawn():
	velocity = Vector2.ZERO
	global_position = posicion_inicio
	estado_actual = Estado.IDLE
	animaciones.play("IDLE")
	animaciones.modulate = Color.WHITE
	es_invulnerable = false

func game_over_total():
	juego_terminado.emit()
	esperando_reinicio = true

func _on_anim_finished():
	hitbox_ataque.disabled = true 
	if estado_actual in [Estado.ATACANDO]:
		cambiar_estado(Estado.IDLE, true)

func _on_hitbox_ataque_body_entered(body):
	if body.is_in_group("rompible"):
		if estado_actual in [Estado.ATACANDO, Estado.BARRIDO, Estado.GROUND_POUND]:
			if body.has_method("romper"): body.romper()
			else: body.queue_free()
				
	elif body.is_in_group("enemigo"):
		if estado_actual in [Estado.BARRIDO, Estado.ATACANDO, Estado.GROUND_POUND]:
			if body.has_method("morir"): body.morir()
			else: body.queue_free()
			
			if estado_actual == Estado.GROUND_POUND:
				hitbox_ataque.disabled = true
				cambiar_estado(Estado.SALTANDO, true)

func _on_hurtbox_body_entered(body):
	if body.is_in_group("enemigo"):
		var esta_en_barrido = (estado_actual == Estado.BARRIDO)
		
		if not es_invulnerable and not esta_en_barrido:
			print("¡Mi Hurtbox tocó al Dummy! Me muero AAA")
			morir()
