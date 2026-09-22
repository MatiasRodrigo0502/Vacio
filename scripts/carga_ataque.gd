## Aviso visual del ataque cargado: la bola que se forma delante del mago.
##
## POR QUE UN NODO APARTE Y NO DIBUJARLO EN EL JUGADOR:
## el sprite del mago es hijo del jugador, asi que lo que pinte el jugador en
## su _draw() sale DEBAJO del personaje. La carga tiene que verse por delante,
## y ademas asi el efecto es un archivo suelto que se puede cambiar sin tocar
## la logica del jugador.
##
## POR QUE DELANTE Y NO ALREDEDOR:
## puesta en la direccion a la que apuntas, la bola dice dos cosas a la vez:
## cuanto llevas cargado y hacia donde va a salir. Un aro alrededor del mago
## solo diria lo primero.
class_name CargaAtaque
extends Node2D

## Color de la carga. Morado como el orbe del baculo, para que se distinga del
## disparo normal, que es azul.
const COLOR_CARGA := Color(0.62, 0.36, 0.95)
const COLOR_LISTO := Color(0.80, 0.62, 1.0)

## Cuanto llevas cargado, de 0 a 1. Lo pone el jugador.
var progreso: float = 0.0
## Hacia donde apunta la carga.
var direccion: Vector2 = Vector2.DOWN

var _fase: float = 0.0


func _ready() -> void:
	visible = false
	# Sin carga no hay nada que animar: el _process se enciende con la carga.
	set_process(false)


func _process(delta: float) -> void:
	_fase += delta
	queue_redraw()


## La llama el jugador en cada paso mientras se mantiene el boton.
func actualizar(nuevo_progreso: float, nueva_direccion: Vector2) -> void:
	progreso = clampf(nuevo_progreso, 0.0, 1.0)
	if nueva_direccion != Vector2.ZERO:
		direccion = nueva_direccion
	if not visible:
		visible = true
		set_process(true)
		_fase = 0.0
	queue_redraw()


func apagar() -> void:
	progreso = 0.0
	visible = false
	set_process(false)


func esta_lista() -> bool:
	return progreso >= 1.0


func _draw() -> void:
	if progreso <= 0.0:
		return

	# Se aleja del mago y crece a la vez: el movimiento hacia fuera se lee mejor
	# que el tamano solo, sobre todo con el sprite tan oscuro de fondo.
	var centro := direccion * (15.0 + 13.0 * progreso)
	var radio := 2.5 + 9.5 * progreso
	var color := COLOR_CARGA.lerp(COLOR_LISTO, progreso)

	# Cuando esta lista late, y solo entonces: el latido es la senal de "ya".
	# Mientras carga se mantiene quieta para que crecer sea lo unico que se vea.
	var pulso := 1.0 + (sin(_fase * 16.0) * 0.16 if esta_lista() else 0.0)

	# Estela corta hacia el mago, para que la bola parezca salir de su mano.
	for i in 3:
		var t := float(i) / 3.0
		draw_circle(centro - direccion * (radio * (1.4 + i * 1.1)),
			radio * (0.55 - t * 0.3), Color(color.r, color.g, color.b, 0.22 - t * 0.12))

	draw_circle(centro, radio * 2.1 * pulso, Color(color.r, color.g, color.b, 0.20))
	draw_circle(centro, radio * pulso, Color(color.r, color.g, color.b, 0.92))
	draw_circle(centro - direccion * radio * 0.25, radio * 0.45 * pulso,
		Color(1.0, 1.0, 1.0, 0.9))

	if esta_lista():
		# Aro de "cargada": cerrado del todo, frente al arco de mientras carga.
		draw_arc(centro, radio * 2.9 * pulso, 0.0, TAU, 28,
			Color(COLOR_LISTO.r, COLOR_LISTO.g, COLOR_LISTO.b, 0.75), 2.0, true)
	else:
		# Arco que se va cerrando: dice cuanto falta sin numeros ni barra.
		draw_arc(centro, radio * 2.9, -PI * 0.5, -PI * 0.5 + TAU * progreso, 24,
			Color(color.r, color.g, color.b, 0.55), 1.5, true)
