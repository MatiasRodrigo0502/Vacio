## Minimapa del piso: las salas que conoces, en una esquina de la pantalla.
##
## POR QUE HACE FALTA:
## en el pasillo no habia donde perderse. Con diez salas del mismo tamano en el
## piso 12, sin mapa se acaba dando vueltas por las mismas.
##
## QUE SE VE (las reglas de Isaac):
## - las salas en las que has estado, rellenas;
## - las de al lado de una visitada, solo el contorno: sabes que ahi hay algo,
##   pero no que;
## - el resto, nada. El mapa se descubre andando, que es lo que hace que
##   explorar tenga sentido;
## - la sala en la que estas, resaltada;
## - el objeto y la bajada, con su marca en cuanto se conoce su sala: saber
##   donde estan es justo para lo que sirve un mapa.
class_name Minimapa
extends Control

## Tamano de cada sala en el mapa. Mas ancha que alta, como las salas de verdad.
const CELDA: Vector2 = Vector2(22.0, 14.0)
const HUECO: float = 4.0
const MARGEN: float = 10.0

const COLOR_FONDO := Color(0.0, 0.0, 0.0, 0.45)
const COLOR_ACTUAL := Color(1.0, 0.92, 0.78)
const COLOR_VISITADA := Color(0.55, 0.49, 0.44)
const COLOR_CONOCIDA := Color(0.55, 0.49, 0.44, 0.6)
const COLOR_OBJETO := Color(1.0, 0.8, 0.3)
## El jefe: rojo, que no se confunda con lo que se recoge.
const COLOR_JEFE := Color(1.0, 0.36, 0.24)

var _piso: Piso = null


## Enseña el mapa de un piso. La llama el HUD al empezar cada piso.
func mostrar(piso: Piso) -> void:
	_piso = piso
	queue_redraw()


## Se redibuja cada fotograma. Son diez rectangulos como mucho, asi que sale
## gratis, y es mucho menos codigo que enganchar una senal por cada cosa que
## puede cambiar el mapa (entrar en una sala, limpiarla, descubrir otra).
func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_piso):
		return

	var visitadas := {}
	for sala in _piso.salas():
		if sala.visitada:
			visitadas[sala.celda] = true

	var conocidas: Array[Sala] = []
	for sala in _piso.salas():
		# La sala secreta no sale hasta que se rompe la pared que la tapa: ni
		# en contorno, que es justo lo que la delataria.
		if sala.oculta:
			continue
		if visitadas.has(sala.celda):
			conocidas.append(sala)
			continue
		for direccion in sala.puertas:
			if visitadas.has(sala.celda + direccion):
				conocidas.append(sala)
				break
	if conocidas.is_empty():
		return

	# Lo que ocupa cada sala, en casillas: la del jefe es mas grande que una.
	var cajas := {}
	for sala in conocidas:
		cajas[sala] = _piso.casillas_de(sala)

	# Se centra lo que se conoce, no el mapa entero: si no, las salas por
	# descubrir delatarian por donde sigue el piso con el hueco que dejan.
	var todo: Rect2 = cajas[conocidas[0]]
	for sala in conocidas:
		todo = todo.merge(cajas[sala])

	var paso := CELDA + Vector2(HUECO, HUECO)
	var ocupado := todo.size * paso - Vector2(HUECO, HUECO)
	var disponible := size - Vector2(MARGEN, MARGEN) * 2.0
	# Si el mapa conocido no cabe, se encoge entero en vez de recortarse.
	var escala := minf(1.0, minf(disponible.x / ocupado.x, disponible.y / ocupado.y))
	var origen := (size - ocupado * escala) * 0.5

	draw_rect(Rect2(Vector2.ZERO, size), COLOR_FONDO)
	for sala in conocidas:
		var caja: Rect2 = cajas[sala]
		var rect := Rect2(origen + (caja.position - todo.position) * paso * escala,
			(caja.size * paso - Vector2(HUECO, HUECO)) * escala)
		if sala == _piso.sala_actual():
			draw_rect(rect, COLOR_ACTUAL)
		elif visitadas.has(sala.celda):
			draw_rect(rect, COLOR_VISITADA)
		else:
			draw_rect(rect, COLOR_CONOCIDA, false, 1.5)
		_pintar_marca(sala, rect)


func _pintar_marca(sala: Sala, rect: Rect2) -> void:
	var centro := rect.get_center()
	var radio := minf(rect.size.x, rect.size.y) * 0.3
	match sala.tipo:
		MapaSalas.Tipo.OBJETO:
			# Un rombo dorado: el color que el juego usa para lo que se recoge.
			var puntos := PackedVector2Array([
				centro + Vector2(0.0, -radio), centro + Vector2(radio, 0.0),
				centro + Vector2(0.0, radio), centro + Vector2(-radio, 0.0)])
			draw_colored_polygon(puntos, COLOR_OBJETO)
		MapaSalas.Tipo.SALIDA:
			_pintar_bajada(sala, centro, radio)
		MapaSalas.Tipo.SECRETA:
			# El cofre, mientras no se ha abierto: un rectangulo dorado.
			var cofre := sala.get_node_or_null("Cofre") as Cofre
			if cofre != null and not cofre.abierto:
				draw_rect(Rect2(centro - Vector2(radio, radio * 0.7), Vector2(radio * 2.0, radio * 1.4)),
					COLOR_OBJETO)
		MapaSalas.Tipo.JEFE:
			# Una estrella de ocho puntas roja, que se ve desde que se conoce
			# la sala (al pisar la antesala): ahi esta la pelea final. Con la
			# bajada dentro cuando ya se puede bajar.
			var puntos := PackedVector2Array()
			for i in 16:
				var largo := radio * (1.5 if i % 2 == 0 else 0.6)
				puntos.append(centro + Vector2.UP.rotated(i * TAU / 16.0) * largo)
			draw_colored_polygon(puntos, COLOR_JEFE)
			if sala.esta_despejada():
				_pintar_bajada(sala, centro, radio * 0.55)


## El agujero: oscuro, con aro. El aro se enciende cuando la sala esta limpia
## y ya se puede bajar.
func _pintar_bajada(sala: Sala, centro: Vector2, radio: float) -> void:
	draw_circle(centro, radio, Color(0.05, 0.03, 0.03))
	var aro := COLOR_OBJETO if sala.esta_despejada() else Color(0.5, 0.45, 0.4)
	draw_arc(centro, radio, 0.0, TAU, 16, aro, 1.5, true)
