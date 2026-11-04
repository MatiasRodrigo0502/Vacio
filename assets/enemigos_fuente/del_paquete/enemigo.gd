extends CharacterBody2D
## Enemigo genérico de Vacío: Gólem (cuerpo a cuerpo), Vigía (a distancia) o Murciélago (enjambre).
##
## Escena:  CharacterBody2D (este script)
##            ├─ AnimatedSprite2D   (vacío: las animaciones se crean por código)
##            ├─ CollisionShape2D   (círculo en los pies)
##            └─ EstadoAlterado     (opcional, para veneno y ralentización)
##
## Valores recomendados:
##   Gólem:      carpeta "golem",      vida 8, velocidad 45,  rango_ataque 56,  frame_golpe 3, desfase_pies (0, -49)
##   Vigía:      carpeta "vigia",      vida 4, velocidad 55,  rango_ataque 220, distancia_preferida 160,
##               frame_golpe 3, desfase_pies (0, -37), proyectil = esquirla.tscn
##   Murciélago: carpeta "murcielago", vida 1, velocidad 120, rango_ataque 28,  frame_golpe 2, desfase_pies (0, -26)
##               columnas atacar = 4, muerte = 6
## El jugador debe estar en el grupo "jugador" y tener recibir_danio(cantidad).

enum Tipo { CUERPO_A_CUERPO, DISTANCIA, ENJAMBRE }

@export var tipo := Tipo.CUERPO_A_CUERPO
@export var carpeta := "golem"                 # dentro de res://enemigos/
@export_enum("corteza", "manto", "nucleo") var capa := "corteza"
@export var vida := 8
@export var velocidad := 45.0
@export var danio := 1
@export var rango_ataque := 56.0
@export var distancia_preferida := 0.0         # solo el Vigía: retrocede si el jugador se acerca más
@export var enfriamiento := 1.2                # segundos entre ataques
@export var frame_golpe := 3                   # frame de "atacar" en el que golpea o dispara
@export var proyectil: PackedScene
@export var desfase_pies := Vector2(0, -49)    # para que el origen del nodo quede en los pies (Y-sort)
@export var columnas := {"caminar": 4, "atacar": 6, "dano": 3, "muerte": 8}
@export var fps := {"caminar": 8.0, "atacar": 12.0, "dano": 12.0, "muerte": 10.0}

var multiplicador_velocidad := 1.0             # lo cambia EstadoAlterado (ralentizar)
var _empuje := Vector2.ZERO                    # lo usa el agujero negro
var _fila := 2
var _estado := "caminar"
var _puede_atacar := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("objetivos")                  # los hechizos de los magos buscan este grupo
	var anims := []
	for nombre in columnas:
		anims.append({
			"nombre": nombre,
			"textura": load("res://enemigos/%s/%s_%s_%s.png" % [carpeta, carpeta, capa, nombre]),
			"columnas": columnas[nombre], "fps": fps[nombre], "bucle": nombre == "caminar",
		})
	sprite.sprite_frames = SpriteFrames8Dir.construir(anims)
	sprite.offset = desfase_pies
	sprite.frame_changed.connect(_al_cambiar_frame)
	sprite.animation_finished.connect(_al_terminar_animacion)
	_reproducir("caminar")


func _physics_process(delta: float) -> void:
	if _estado == "muerte":
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Node2D
	if jugador == null:
		return
	var hacia := jugador.global_position - global_position
	var distancia := hacia.length()
	var dir := hacia / maxf(distancia, 0.001)
	var mover := Vector2.ZERO

	if _estado == "caminar":
		_fila = SpriteFrames8Dir.fila(dir)
		if distancia <= rango_ataque and _puede_atacar:
			_atacar()
		elif tipo == Tipo.DISTANCIA and distancia < distancia_preferida:
			mover = -dir                       # se aleja para seguir disparando desde lejos
		elif distancia > rango_ataque * 0.8:
			mover = dir
		if _estado == "caminar":
			_reproducir("caminar")

	velocity = mover * velocidad * multiplicador_velocidad + _empuje
	_empuje = _empuje.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()


func _atacar() -> void:
	_estado = "atacar"
	_puede_atacar = false
	_reproducir("atacar")
	get_tree().create_timer(enfriamiento).timeout.connect(func(): _puede_atacar = true)


func _al_cambiar_frame() -> void:
	if _estado != "atacar" or sprite.frame != frame_golpe:
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Node2D
	if jugador == null:
		return
	if tipo == Tipo.DISTANCIA and proyectil:
		var p := proyectil.instantiate()
		p.direccion = (jugador.global_position - global_position).normalized()
		p.global_position = global_position + p.direccion * 24.0 + desfase_pies * 0.6
		get_tree().current_scene.add_child(p)
	elif global_position.distance_to(jugador.global_position) <= rango_ataque * 1.25:
		if jugador.has_method("recibir_danio"):
			jugador.recibir_danio(danio)


func _al_terminar_animacion() -> void:
	if _estado == "muerte":
		var t := create_tween()                # los restos se desvanecen
		t.tween_interval(1.5)
		t.tween_property(self, "modulate:a", 0.0, 0.8)
		t.tween_callback(queue_free)
	elif _estado in ["atacar", "dano"]:
		_estado = "caminar"
		_reproducir("caminar")


func recibir_danio(cantidad: int) -> void:
	if _estado == "muerte":
		return
	vida -= cantidad
	if vida <= 0:
		_estado = "muerte"
		remove_from_group("objetivos")
		$CollisionShape2D.set_deferred("disabled", true)
		_reproducir("muerte")
	else:
		_estado = "dano"
		_reproducir("dano")


## El agujero negro llama a esto cada frame con un vector en píxeles/segundo.
func empujar(fuerza: Vector2) -> void:
	_empuje = fuerza


func _reproducir(nombre: String) -> void:
	var anim := "%s_%d" % [nombre, _fila]
	if sprite.animation == anim and sprite.is_playing():
		return
	if nombre == "caminar" and sprite.animation.begins_with("caminar"):
		# al girar mientras camina, conservamos el frame para que el paso no "salte"
		var frame := sprite.frame
		var progreso := sprite.frame_progress
		sprite.play(anim)
		sprite.set_frame_and_progress(frame, progreso)
	else:
		sprite.play(anim)
