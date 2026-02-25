extends CharacterBody2D

const GRAVEDAD = 980.0

func _ready():
	if not is_in_group("enemigo"):
		add_to_group("enemigo")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVEDAD * delta
	move_and_slide()

func morir():
	print("¡Dummy destruido!")
	queue_free()

func _on_hitbox_daño_area_entered(area):
	print("🚨 LA HITBOX DETECTÓ UN ÁREA: ", area.name)
	
	var jugador = area.get_parent()
	
	if jugador and jugador.has_method("morir"):
		var esta_en_barrido = false
		var esta_en_dash = false
		
		if "es_invulnerable" in jugador:
			esta_en_barrido = jugador.es_invulnerable
		if "estado_actual" in jugador and "Estado" in jugador:
			esta_en_dash = (jugador.estado_actual == jugador.Estado.DASH)
			
		if not esta_en_barrido and not esta_en_dash:
			print("💀 ¡Hurtbox alcanzada! Muerte instantánea.")
			jugador.morir()
