extends CharacterBody2D

const GRAVEDAD = 980.0

# =========================================================
# VARIABLES
# =========================================================
@export_group("Inteligencia y Movimiento")
@export var distancia_patrullaje: float = 50.0
@export var radio_deteccion: float = 50.0
@export var velocidad_patrullaje: float = 25.0
@export var velocidad_persecucion: float = 50.0

# VARIABLES DIRECCIONALES
var posicion_inicio: float
var direccion_x: float = 1.0
var persiguiendo: bool = false
var jugador_referencia: Node2D = null

func _ready():
	if not is_in_group("enemigo"):
		add_to_group("enemigo")
		
	posicion_inicio = global_position.x
	
	var jugadores_en_mapa = get_tree().get_nodes_in_group("jugador")
	if jugadores_en_mapa.size() > 0:
		jugador_referencia = jugadores_en_mapa[0]

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta
		
	if jugador_referencia and is_instance_valid(jugador_referencia):
		var distancia_al_jugador = global_position.distance_to(jugador_referencia.global_position)
		
		if distancia_al_jugador < radio_deteccion:
			persiguiendo = true 
		else:
			persiguiendo = false 
			
	if persiguiendo and jugador_referencia and is_instance_valid(jugador_referencia):
		var dir_hacia_jugador = sign(jugador_referencia.global_position.x - global_position.x)
		velocity.x = dir_hacia_jugador * velocidad_persecucion
	else:
		velocity.x = direccion_x * velocidad_patrullaje
		
		if global_position.x > posicion_inicio + distancia_patrullaje:
			direccion_x = -1 
		elif global_position.x < posicion_inicio - distancia_patrullaje:
			direccion_x = 1  
			
	move_and_slide()

# =========================================================
# FUNCIONES
# =========================================================
func morir():
	print("¡Dummy destruido!")
	queue_free()



func _on_hitbox_daño_body_entered(body):
	if body.has_method("morir") and body.name != self.name:
		
		var a_salvo = false
		
		if "es_invulnerable" in body and body.es_invulnerable:
			a_salvo = true 
		if "estado_actual" in body and "Estado" in body:
			if body.estado_actual == body.Estado.DASH or body.estado_actual == body.Estado.ROLL:
				a_salvo = true
		
		if not a_salvo:
			print("Dummy mató al jugador")
			body.morir()
