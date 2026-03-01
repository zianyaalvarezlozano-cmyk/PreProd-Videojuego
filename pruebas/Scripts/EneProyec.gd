extends CharacterBody2D

const GRAVEDAD = 980.0

@export_group("Combate y Visión")
@export var escena_bala : PackedScene
@export var tiempo_disparo: float = 2.0
@export var radio_deteccion: float = 180.0 #

var timer_disparo: float = 0.0
var jugador_referencia : Node2D

func _ready():
	if not is_in_group("enemigo"):
		add_to_group("enemigo")
		
	var jugadores_en_mapa = get_tree().get_nodes_in_group("jugador")
	if jugadores_en_mapa.size() > 0:
		jugador_referencia = jugadores_en_mapa[0]

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta
	move_and_slide()
	
	# ==========================================
	# RADAR DE VISIÓN
	# ==========================================
	if jugador_referencia and is_instance_valid(jugador_referencia):
		
		var distancia_al_jugador = global_position.distance_to(jugador_referencia.global_position)
		
		if distancia_al_jugador <= radio_deteccion:
			timer_disparo += delta
			if timer_disparo >= tiempo_disparo:
				disparar()
				timer_disparo = 0.0
		else:
			timer_disparo = 0.0

func disparar():
	if escena_bala:
		var nueva_bala = escena_bala.instantiate()
		get_parent().add_child(nueva_bala)
		nueva_bala.global_position = global_position
		
		# ==========================================
		# APUNTADO
		# ==========================================
		if jugador_referencia and is_instance_valid(jugador_referencia):
			var direccion_apuntado = (jugador_referencia.global_position - global_position).normalized()
			nueva_bala.direccion = direccion_apuntado
		else:
			nueva_bala.direccion = Vector2.LEFT 
	else:
		print("No pusiste la escena de bala en el enemigo.")

func morir():
	print("¡Enemigo proyectil muerto!")
	queue_free()
