## Fila del HUD con las ventajas recogidas en la partida: el icono de cada una,
## con un aro de su color, y "x2", "x3"... si se ha cogido mas de una vez.
##
## POR QUE HACE FALTA:
## el aviso que sale al coger un objeto se va a los pocos segundos. Sin esta
## fila, dos pisos despues ya no sabes que llevas encima, y las mejoras se
## acumulan toda la partida.
##
## Solo salen las ventajas que duran. Lo que solo cura (el vendaje) se gasta
## al cogerlo y no se queda contigo: no pinta nada en la fila.
class_name MejorasRecogidas
extends Control

## Diametro de cada icono y hueco entre iconos.
const LADO: float = 34.0
const HUECO: float = 8.0
## Lo que dura el saltito del icono al aparecer, o al subir su cuenta.
const APARECER: float = 0.3

## Una entrada por ventaja distinta: {mejora, cantidad, tiempo}.
var _lista: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Solo hace falta redibujar mientras algun icono esta saltando.
	set_process(false)


## Apunta una ventaja recien cogida. Si ya estaba, sube su cuenta.
func anadir(mejora: ObjetoMejora) -> void:
	if mejora == null or mejora.icono == null or not mejora.es_permanente():
		return
	for entrada in _lista:
		if entrada["mejora"] == mejora:
			entrada["cantidad"] += 1
			entrada["tiempo"] = 0.0
			set_process(true)
			return
	_lista.append({"mejora": mejora, "cantidad": 1, "tiempo": 0.0})
	set_process(true)


## Deja la fila vacia. Al empezar otra partida las mejoras se pierden.
func vaciar() -> void:
	_lista.clear()
	queue_redraw()


func cuantas() -> int:
	return _lista.size()


func _process(delta: float) -> void:
	var saltando := false
	for entrada in _lista:
		if entrada["tiempo"] < APARECER:
			entrada["tiempo"] += delta
			saltando = true
	queue_redraw()
	if not saltando:
		set_process(false)


func _draw() -> void:
	var fuente := get_theme_default_font()
	for i in _lista.size():
		var entrada: Dictionary = _lista[i]
		var mejora: ObjetoMejora = entrada["mejora"]
		var centro := Vector2(LADO * 0.5 + i * (LADO + HUECO), size.y * 0.5)
		# Crece y vuelve: se ve entrar sin tener que buscarlo.
		var avance := clampf(entrada["tiempo"] / APARECER, 0.0, 1.0)
		var salto := 1.0 + sin(avance * PI) * 0.35
		var radio := LADO * 0.5 * salto

		draw_circle(centro, radio, Color(0.0, 0.0, 0.0, 0.5))
		draw_arc(centro, radio, 0.0, TAU, 28, Color(mejora.color, 0.9), 2.0, true)
		var icono := mejora.icono
		var escala := LADO * 0.7 * salto / maxf(icono.get_width(), icono.get_height())
		var tam := icono.get_size() * escala
		draw_texture_rect(icono, Rect2(centro - tam * 0.5, tam), false)

		if entrada["cantidad"] > 1:
			var texto := "x%d" % entrada["cantidad"]
			var sitio := centro + Vector2(LADO * 0.12, LADO * 0.62)
			# Con sombra: encima del juego, un numero sin sombra no se lee.
			draw_string(fuente, sitio + Vector2(1, 1), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
			draw_string(fuente, sitio, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
