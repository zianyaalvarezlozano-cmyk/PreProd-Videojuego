extends Area2D

@export var nodo_destino: Marker2D 
@export var texto_puerta: String = "Destino" 

var jugador_en_rango: bool = false
var jugador_ref: Node2D = null

@onready var letrero = $Label 

func _ready():
	if letrero:
		letrero.text = texto_puerta

	if not body_entered.is_connected(_al_entrar):
		body_entered.connect(_al_entrar)
	if not body_exited.is_connected(_al_salir):
		body_exited.connect(_al_salir)

func _al_entrar(body):
	if body.is_in_group("jugador") or body.has_method("morir"):
		jugador_en_rango = true
		jugador_ref = body

func _al_salir(body):
	if body == jugador_ref:
		jugador_en_rango = false
		jugador_ref = null

func _process(delta):
	if jugador_en_rango and Input.is_action_just_pressed("ui_up"):
		if nodo_destino:
			jugador_ref.global_position = nodo_destino.global_position
