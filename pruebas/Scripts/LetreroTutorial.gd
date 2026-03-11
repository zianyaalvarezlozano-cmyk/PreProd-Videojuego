extends Area2D

# =========================================================
# ⚙️ VARIABLES PARA EL INSPECTOR
# =========================================================
# Escribe aquí el nombre exacto de la animación que hiciste (ej: "flechas", "z")
@export var nombre_animacion: String = "flechas"

@export_multiline var texto_instruccion: String = "Presiona flechas\npara moverte"

@onready var visual = $ContenedorVisual
@onready var boton = $ContenedorVisual/BotonAnimado
@onready var letrero = $ContenedorVisual/Texto

func _ready():
	if boton.sprite_frames.has_animation(nombre_animacion):
		boton.play(nombre_animacion)
	else:
		print("⚠️ Ojo: No existe la animación '", nombre_animacion, "' en tu AnimatedSprite2D")
		
	letrero.text = texto_instruccion
	
	visual.modulate.a = 0.0
	
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)

func _al_entrar(body):
	if body.is_in_group("jugador"):
		var tween = create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.3)

func _al_salir(body):
	if body.is_in_group("jugador"):
		var tween = create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.3)
