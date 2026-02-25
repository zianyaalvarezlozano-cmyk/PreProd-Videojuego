extends Area2D

@export var velocidad: float = 300.0
var direccion: Vector2 = Vector2.LEFT
var fue_desviado: bool = false

func _ready():
	set_collision_mask_value(1, true) 
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)

	if not body_entered.is_connected(_al_chocar):
		body_entered.connect(_al_chocar)

func _physics_process(delta):
	position += direccion * velocidad * delta

func _al_chocar(body: Node2D):
	print("🔍 La bala tocó a: ", body.name) 
	
	if body.is_in_group("jugador") or body.has_method("morir"):
		var esta_en_barrido = false
		var esta_en_dash = false
		
		if "es_invulnerable" in body: esta_en_barrido = body.es_invulnerable
		if "estado_actual" in body and "Estado" in body: esta_en_dash = (body.estado_actual == body.Estado.DASH)
		
		if esta_en_barrido: 
			return 
			
		if "estado_actual" in body and body.estado_actual == body.Estado.PARRY:
			print("🛡️ ¡PARRY PERFECTO! La bala rebota.")
			direccion *= -1 
			fue_desviado = true
			modulate = Color(0, 2, 0)
			return

		if not fue_desviado:
			print("Proyectil mató al jugador")
			body.morir()
			queue_free()

	elif body.is_in_group("enemigo") and fue_desviado:
		if body.has_method("morir"):
			print("Mataste por rebote")
			body.morir()
		queue_free()
