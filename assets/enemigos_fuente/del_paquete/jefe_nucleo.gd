extends CharacterBody2D
## Jefe final (nivel 12, núcleo interno): el Corazón del Núcleo.
## Flota hacia el jugador y cada pocos segundos carga una NOVA: daña alrededor y
## dispara un anillo de 8 bolas de magma. Por debajo del 50 % de vida entra en furia.
##
## Escena:  CharacterBody2D (este script)
##            ├─ AnimatedSprite2D   (las animaciones se crean por código)
##            └─ CollisionShape2D   (círculo grande, radio ~80)
## proyectil: una escena con proyectil_magico.gd usando jefe_bola_vuelo/impacto.png
##            (desfase_cabeza (-26, 0), desfase_impacto (0, 2))

signal derrotado

@export var vida_maxima := 120
@export var velocidad := 32.0
@export var proyectil: PackedScene
@export var radio_nova := 170.0
@export var danio_nova := 2
@export var intervalo_ataque := 3.5
@export var desfase := Vector2(0, -148)        # el origen del nodo queda en el suelo, bajo el jefe

var vida := 0
var multiplicador_velocidad := 1.0
var _empuje := Vector2.ZERO
var _fila := 2
var _estado := "flotar"
var _tiempo := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	vida = vida_maxima
	add_to_group("objetivos")
	var base := "res://enemigos/jefe/jefe_%s.png"
	sprite.sprite_frames = SpriteFrames8Dir.construir([
		{"nombre": "flotar", "textura": load(base % "flotar"), "columnas": 6, "fps": 8.0, "bucle": true},
		{"nombre": "atacar", "textura": load(base % "atacar"), "columnas": 8, "fps": 10.0, "bucle": false},
		{"nombre": "dano", "textura": load(base % "dano"), "columnas": 3, "fps": 12.0, "bucle": false},
		{"nombre": "muerte", "textura": load(base % "muerte"), "columnas": 10, "fps": 8.0, "bucle": false},
	])
	sprite.offset = desfase
	sprite.frame_changed.connect(_al_cambiar_frame)
	sprite.animation_finished.connect(_al_terminar_animacion)
	_reproducir("flotar")


func _physics_process(delta: float) -> void:
	if _estado == "muerte":
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Node2D
	if jugador == null:
		return
	var hacia := jugador.global_position - global_position
	var furia := 1.6 if vida < vida_maxima * 0.5 else 1.0
	if _estado == "flotar":
		_fila = SpriteFrames8Dir.fila(hacia)
		_reproducir("flotar")
		_tiempo += delta * furia
		if _tiempo >= intervalo_ataque:
			_tiempo = 0.0
			_estado = "atacar"
			_reproducir("atacar")
	var mover := hacia.normalized() if _estado == "flotar" else Vector2.ZERO
	velocity = mover * velocidad * furia * multiplicador_velocidad + _empuje * 0.2   # al jefe casi no le afecta el agujero negro
	_empuje = _empuje.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()


func _al_cambiar_frame() -> void:
	if _estado != "atacar" or sprite.frame != 4:   # frame 4 = la onda sale
		return
	for o in get_tree().get_nodes_in_group("jugador"):
		if o.global_position.distance_to(global_position) <= radio_nova and o.has_method("recibir_danio"):
			o.recibir_danio(danio_nova)
	if proyectil:
		var giro := randf() * TAU / 8.0            # cada anillo sale un poco girado
		for i in 8:
			var p := proyectil.instantiate()
			p.direccion = Vector2.RIGHT.rotated(giro + i * TAU / 8.0)
			p.global_position = global_position + Vector2(0, -60) + p.direccion * 90.0
			get_tree().current_scene.add_child(p)


func _al_terminar_animacion() -> void:
	if _estado == "muerte":
		derrotado.emit()
	elif _estado in ["atacar", "dano"]:
		_estado = "flotar"
		_reproducir("flotar")


func recibir_danio(cantidad: int) -> void:
	if _estado == "muerte":
		return
	vida -= cantidad
	if vida <= 0:
		_estado = "muerte"
		remove_from_group("objetivos")
		$CollisionShape2D.set_deferred("disabled", true)
		_reproducir("muerte")
	elif _estado == "flotar":                       # no interrumpe la nova: así es más "jefe"
		_estado = "dano"
		_reproducir("dano")


func empujar(fuerza: Vector2) -> void:
	_empuje = fuerza


func _reproducir(nombre: String) -> void:
	var anim := "%s_%d" % [nombre, _fila]
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
