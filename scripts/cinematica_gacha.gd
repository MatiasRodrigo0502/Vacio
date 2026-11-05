## La cinematica de abrir el gacha. Pedida por Matias el 2026-11-05: la de
## antes (una interrogacion que cambiaba de color y el premio de golpe) era
## «muy basica», y lo de los dos tiers de arriba tenia que tener la suya.
##
## Todas empiezan igual: un circulo de runas, chispas que van al centro y un
## orbe que crece y cambia de color de tier en tier hasta el que ha salido (el
## mejor, si son diez). Cuanto mas alto, mas dura, y lo de arriba avisa: antes
## del tercer tier caen rayos sobre el orbe y antes del cuarto se agrieta. Luego
## revienta y:
##
## - tiers de abajo: sale con rayos de su color detras;
## - el tercero (S o legendaria): todo a negro, una franja de su color con el
##   sello del tier que cae y hace temblar la pantalla, la silueta, y una luz
##   que la barre y le da color; el nombre, letra a letra;
## - el cuarto (S+ o mitica): un destello, estrellas que pasan como a la
##   velocidad de la luz en arcoiris, la S y luego el + que caen con los colores
##   corridos, y la skin girando hasta pararse de frente (el arma, dando vueltas),
##   con confeti.
##
## Diez de golpe: el orbe se parte en diez que van a sus cartas, boca abajo y
## del color de su tier, y se dan la vuelta una a una. Antes de una de los dos
## tiers de arriba la carta tiembla y sale su cinematica entera.
##
## Un clic adelanta lo que se esta viendo; «Saltar» (o Escape) va al final. El
## premio ya esta dado antes de empezar (Coleccion.tirar): saltar no cambia nada.
##
## Todo dibujado por codigo (_draw) salvo lo que sale, que es un GiroGacha. Sin
## particulas de Godot: unas pocas cuentas por fotograma bastan y se ven igual
## en todos los sistemas, tambien en el movil.
class_name CinematicaGacha
extends Control

## Se ha cerrado (Seguir).
signal terminada
## Quiere tirar otra vez las mismas veces.
signal otra_vez(veces: int)

enum Fase { INVOCAR, ESTALLIDO, REPARTIR, VOLTEAR, ENTRADA, MOSTRAR, RESUMEN }

const FONDO := Color(0.02, 0.016, 0.04)
## La parte comun. Los dos tiers de arriba la alargan medio segundo cada uno:
## la espera es parte de la emocion, pero solo cuando hay algo que esperar.
const INVOCAR: float = 1.5
const INVOCAR_EXTRA: float = 0.5
const ESTALLIDO: float = 0.4
const REPARTIR: float = 0.55
const ENTRE_CARTAS: float = 0.16
const VUELTA: float = 0.24
## Lo que tiembla una carta de los tiers de arriba antes de darse la vuelta.
const AVISO_CARTA: float = 0.7
const ENTRADA_ALTA: float = 1.7
const ENTRADA_MAXIMA: float = 2.6
## Las letras por segundo del nombre, en las de arriba.
const LETRAS: float = 28.0
## Medidas a 1152 x 648: todo se escala con la pantalla.
const BASE := Vector2(1152.0, 648.0)
const CARTA := Vector2(150.0, 200.0)
const HUECO: float = 14.0

var _tirada: TiradaGacha
var _resultados: Array[Dictionary] = []
var _mejor: int = 0
var _fase: int = Fase.INVOCAR
var _t: float = 0.0
## No se reinicia en cada fase: lo que gira o parpadea no da saltos.
var _reloj: float = 0.0
var _escala: float = 1.0

# La invocacion
var _nivel: int = 0
var _subidas: int = 0
var _rayos: Array[Dictionary] = []
var _grieta_desde: float = -1.0

# Las cartas (diez de golpe)
var _volteo: Array[float] = []
## Las de los tiers de arriba que ya han tenido su cinematica.
var _vistas: Dictionary = {}
var _siguiente: int = 0
var _espera_carta: float = 0.0
var _avisando: int = -1

# Lo que se ensena en grande
var _actual: int = 0
var _giro: GiroGacha

# Efectos
var _particulas: Array[Dictionary] = []
var _ondas: Array[Dictionary] = []
var _temblor: float = 0.0
var _destello: float = 0.0
var _desplazado := Vector2.ZERO
## Lo que va por encima de lo que sale (el sello, la luz que barre, el confeti,
## el destello): los hijos se pintan despues que el padre, y lo de _draw quedaba
## tapado por el GiroGacha.
var _encima: Control
## Donde pintan _texto y compania, y con que transformacion.
var _lienzo: CanvasItem = self
var _matriz := Transform2D.IDENTITY

var _botones: HBoxContainer
var _boton_seguir: Button
var _boton_otra: Button
var _boton_saltar: Button


func _init() -> void:
	name = "CinematicaGacha"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Con el foco, las teclas llegan aqui y no al boton de tirar de detras.
	focus_mode = Control.FOCUS_ALL
	visible = false


func _ready() -> void:
	_giro = GiroGacha.new()
	_giro.visible = false
	add_child(_giro)
	_encima = Control.new()
	_encima.set_anchors_preset(Control.PRESET_FULL_RECT)
	_encima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encima.draw.connect(_pintar_encima)
	add_child(_encima)
	_boton_saltar = _boton("Saltar", 16, Vector2(120.0, 36.0))
	_boton_saltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_boton_saltar.offset_left = -140.0
	_boton_saltar.offset_right = -20.0
	_boton_saltar.offset_top = 16.0
	_boton_saltar.offset_bottom = 52.0
	_boton_saltar.pressed.connect(_saltar)
	add_child(_boton_saltar)
	_botones = HBoxContainer.new()
	_botones.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_botones.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_botones.offset_top = -70.0
	_botones.offset_bottom = -22.0
	_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	_botones.add_theme_constant_override("separation", 16)
	add_child(_botones)
	_boton_seguir = _boton("Seguir", 20, Vector2(220.0, 48.0))
	_boton_seguir.pressed.connect(_seguir)
	_botones.add_child(_boton_seguir)
	_boton_otra = _boton("", 18, Vector2(260.0, 48.0))
	_boton_otra.pressed.connect(func() -> void: otra_vez.emit(_resultados.size()))
	_botones.add_child(_boton_otra)


func _boton(texto: String, letra: int, tamano: Vector2) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = tamano
	boton.add_theme_font_size_override("font_size", letra)
	return boton


## Empieza con lo que ya ha salido (lo que devuelven Coleccion.tirar y
## tirar_varias).
func empezar(tirada: TiradaGacha, resultados: Array[Dictionary]) -> void:
	_tirada = tirada
	_resultados = resultados
	_mejor = 0
	for resultado in resultados:
		_mejor = maxi(_mejor, resultado.tier)
	_volteo.clear()
	for i in resultados.size():
		_volteo.append(-1.0)
	_vistas.clear()
	_siguiente = 0
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null:
		foco.release_focus()
	_avisando = -1
	_particulas.clear()
	_ondas.clear()
	_rayos.clear()
	_nivel = 0
	_subidas = 0
	_grieta_desde = -1.0
	_temblor = 0.0
	_destello = 0.0
	_giro.visible = false
	_botones.visible = false
	_boton_saltar.visible = true
	visible = true
	_ir(Fase.INVOCAR)
	Sonido.tocar(&"gacha_carga")
	grab_focus()


func _duracion_invocar() -> float:
	return INVOCAR + INVOCAR_EXTRA * maxi(0, _mejor - 1)


func _ir(fase: int) -> void:
	_fase = fase
	_t = 0.0
	queue_redraw()


# --- El paso del tiempo --------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_escala = minf(size.x / BASE.x, size.y / BASE.y)
	_t += delta
	_reloj += delta
	_temblor = maxf(0.0, _temblor - delta * 2.2)
	_destello = maxf(0.0, _destello - delta * 2.8)
	_desplazado = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _temblor * 16.0 * _escala
	match _fase:
		Fase.INVOCAR:
			_avanzar_invocacion(delta)
		Fase.ESTALLIDO:
			if _t >= ESTALLIDO:
				if _resultados.size() == 1:
					_empezar_revelacion(0)
				else:
					_ir(Fase.REPARTIR)
		Fase.REPARTIR:
			if _t >= REPARTIR:
				_espera_carta = 0.15
				_ir(Fase.VOLTEAR)
		Fase.VOLTEAR:
			_avanzar_cartas(delta)
		Fase.ENTRADA:
			_avanzar_entrada()
		Fase.MOSTRAR:
			_colocar_giro(1.0)
			if _tier_actual() == 3 and randf() < 0.6:
				_soltar_confeti()
			elif _tier_actual() == 2:
				_subir_brillos(2)
	_mover_particulas(delta)
	queue_redraw()
	_encima.queue_redraw()


func _avanzar_invocacion(delta: float) -> void:
	var duracion := _duracion_invocar()
	# Sube de tier en tier hasta el mejor, repartido entre el 30 y el 80 %.
	while _subidas <= _mejor:
		var cuando := duracion * (0.3 + 0.5 * _subidas / maxf(1.0, _mejor))
		if _t < cuando:
			break
		_nivel = _subidas
		_onda(_color_tier(_nivel), 1.0)
		Sonido.tocar(StringName("gacha_sube_%d" % mini(_nivel, 3)))
		if _nivel == 2:
			_temblor = 0.7
			Sonido.tocar(&"gacha_trueno")
			for i in 3:
				_rayos.append({"t": _t + i * 0.12, "semilla": randi()})
		elif _nivel == 3:
			_temblor = 1.0
			_grieta_desde = _t
			Sonido.tocar(&"gacha_grieta")
		_subidas += 1
	# Chispas que vienen de los bordes al orbe.
	if _t < duracion - 0.2:
		for i in 2:
			var angulo := randf() * TAU
			var desde := _orbe() + Vector2.from_angle(angulo) * size.length() * 0.6
			_particulas.append({"p": desde, "v": (_orbe() - desde) * randf_range(1.6, 2.4), "vida": 0.0, "max": 0.5,
				"color": _color_tier(_nivel).lightened(0.3), "r": randf_range(1.5, 3.0) * _escala, "tipo": "chispa",
				"hasta": _orbe()})
	if _t >= duracion:
		_estallar()


func _estallar() -> void:
	_ir(Fase.ESTALLIDO)
	_destello = 1.0
	_temblor = maxf(_temblor, 0.5 + 0.2 * _mejor)
	_onda(_color_tier(_mejor), 2.2)
	Sonido.tocar(&"gacha_estallido")
	for i in 70:
		var color := _arcoiris(randf()) if _mejor == 3 else _color_tier(_mejor).lightened(randf() * 0.5)
		_particulas.append({"p": _orbe(), "v": Vector2.from_angle(randf() * TAU) * randf_range(200.0, 900.0) * _escala,
			"vida": 0.0, "max": randf_range(0.5, 1.1), "color": color, "r": randf_range(2.0, 5.0) * _escala,
			"tipo": "esquirla" if _mejor == 3 and i % 3 == 0 else "chispa", "giro": randf() * TAU})


func _avanzar_cartas(delta: float) -> void:
	# La que esta avisando (un tier de arriba) tiembla y luego sale en grande.
	if _avisando >= 0:
		if _t >= AVISO_CARTA:
			_vistas[_avisando] = true
			_empezar_revelacion(_avisando)
		return
	_espera_carta -= delta
	if _siguiente < _resultados.size() and _espera_carta <= 0.0:
		var tier: int = _resultados[_siguiente].tier
		if tier >= 2 and not _vistas.has(_siguiente):
			_avisando = _siguiente
			_t = 0.0
			_temblor = 0.3
			Sonido.tocar(&"gacha_trueno" if tier == 3 else &"gacha_sube_2")
			return
		_voltear(_siguiente)
		_siguiente += 1
		_espera_carta = ENTRE_CARTAS
	if _siguiente >= _resultados.size() and _todas_vueltas():
		_ir(Fase.RESUMEN)
		_mostrar_botones()


func _voltear(i: int) -> void:
	_volteo[i] = _reloj
	Sonido.tocar(&"gacha_carta", 40)
	if _resultados[i].nuevo:
		for k in 8:
			_particulas.append({"p": _centro_carta(i), "v": Vector2.from_angle(randf() * TAU) * randf_range(60.0, 200.0) * _escala,
				"vida": 0.0, "max": 0.6, "color": _color_tier(_resultados[i].tier).lightened(0.4), "r": 2.5 * _escala, "tipo": "chispa"})


func _todas_vueltas() -> bool:
	for inicio in _volteo:
		if inicio < 0.0 or _reloj - inicio < VUELTA:
			return false
	return true


# --- Lo que se ensena en grande --------------------------------------------------

func _empezar_revelacion(i: int) -> void:
	_actual = i
	_avisando = -1
	_ir(Fase.ENTRADA)
	var resultado := _resultados[i]
	var tier: int = resultado.tier
	_giro.mostrar(resultado.objeto)
	_giro.visible = tier < 2
	_giro.modulate = Color.WHITE
	_giro.rotation = 0.0
	_giro.velocidad = 0.0
	_giro.direccion = 2.0
	_giro.color_tier = Color(_color_tier(tier), 0.0)
	_botones.visible = false
	_boton_saltar.visible = true
	if tier < 2:
		_giro.scale = Vector2.ONE * 0.3
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_giro, "scale", Vector2.ONE, 0.35)
		_onda(_color_tier(tier), 1.4)
		Sonido.tocar(&"gacha_revelar")
	elif tier == 2:
		_destello = 0.8
		_giro.modulate = Color.BLACK
		_giro.scale = Vector2.ONE * 0.92
	else:
		_destello = 1.0
		_temblor = 0.4
		Sonido.tocar(&"gacha_smas")


func _duracion_entrada() -> float:
	match _tier_actual():
		2:
			return ENTRADA_ALTA
		3:
			return ENTRADA_MAXIMA
	return 0.35


func _avanzar_entrada() -> void:
	var tier := _tier_actual()
	if tier == 2:
		if _t >= 0.38 and _t - get_process_delta_time() < 0.38:
			_temblor = 1.0
			_onda(_color_tier(2), 1.6)
			Sonido.tocar(&"gacha_s")
		if _t >= 0.95 and not _giro.visible:
			_giro.visible = true
		# La luz la barre de 1,0 a 1,4 s: de negro a su color.
		var luz := clampf((_t - 1.0) / 0.4, 0.0, 1.0)
		_giro.modulate = Color.BLACK.lerp(Color.WHITE, luz)
		if luz >= 1.0 and _giro.color_tier.a == 0.0:
			_giro.color_tier = _color_tier(2)
		if _t > 1.0:
			_subir_brillos(2)
	elif tier == 3:
		for cuando in [0.55, 0.85]:
			if _t >= cuando and _t - get_process_delta_time() < cuando:
				_temblor = 1.0
				_destello = 0.5
				_onda(_arcoiris(_reloj * 0.3), 2.0)
		if _t >= 1.1:
			_giro.visible = true
			_giro.color_tier = _arcoiris(_reloj * 0.25)
		if _t > 1.6:
			_soltar_confeti()
	_colocar_giro(_progreso_giro())
	if _t >= _duracion_entrada():
		_terminar_entrada()


func _terminar_entrada() -> void:
	var tier := _tier_actual()
	_ir(Fase.MOSTRAR)
	_giro.visible = true
	_giro.modulate = Color.WHITE
	_giro.scale = Vector2.ONE
	_giro.rotation = 0.0
	_giro.direccion = 2.0
	# Ya de frente, se queda dando vueltas despacio, para verla entera.
	_giro.velocidad = 1.6
	_giro.color_tier = _color_tier(tier) if tier < 3 else _arcoiris(0.0)
	_mostrar_botones()


## De 0 a 1, lo que lleva la entrada de la S+ hacia su sitio.
func _progreso_giro() -> float:
	if _tier_actual() != 3:
		return 1.0
	return clampf((_t - 1.1) / 1.3, 0.0, 1.0)


## Pone lo que sale en su sitio, con el temblor; en la S+ ademas gira y crece.
func _colocar_giro(progreso: float) -> void:
	var lado := 330.0 * _escala
	_giro.size = Vector2.ONE * lado
	_giro.pivot_offset = _giro.size * 0.5
	_giro.position = _centro_objeto() - _giro.size * 0.5 + _desplazado
	if _tier_actual() == 3 and _fase == Fase.ENTRADA:
		var frenado := 1.0 - pow(1.0 - progreso, 3.0)
		_giro.scale = Vector2.ONE * lerpf(0.25, 1.0, frenado)
		if _resultados[_actual].objeto is ArmaMago:
			_giro.rotation = -TAU * 2.0 * (1.0 - frenado)
		else:
			# Tres vueltas que acaban justo de frente (la direccion 2).
			_giro.direccion = 2.0 + 24.0 * frenado
	if _fase == Fase.MOSTRAR and _tier_actual() == 3:
		_giro.color_tier = _arcoiris(_reloj * 0.25)


func _tier_actual() -> int:
	return _resultados[_actual].tier if _actual < _resultados.size() else 0


func _mostrar_botones() -> void:
	_boton_saltar.visible = false
	_botones.visible = true
	var en_cartas := _resultados.size() > 1 and _fase == Fase.MOSTRAR
	_boton_otra.visible = not en_cartas
	_boton_seguir.text = "Ver las demás" if en_cartas and not _todas_vistas() else "Seguir"
	if _boton_otra.visible:
		var veces := _resultados.size()
		_boton_otra.text = "Otra vez ×%d · %d %s" % [veces, _tirada.coste_de(veces), _tirada.moneda()]
		_boton_otra.disabled = not Coleccion.puede_tirar(_tirada, veces)
	_boton_seguir.grab_focus()


func _todas_vistas() -> bool:
	return _siguiente >= _resultados.size() and _todas_vueltas()


# --- Lo que hace el jugador -------------------------------------------------------

func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_adelantar()
		accept_event()
	elif evento.is_action_pressed("ui_accept"):
		_adelantar()
		accept_event()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("ui_cancel"):
		if _boton_saltar.visible:
			_saltar()
		else:
			_seguir()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("ui_accept") and not _botones.visible:
		_adelantar()
		get_viewport().set_input_as_handled()


## Un clic: lo que se esta viendo acaba ya.
func _adelantar() -> void:
	match _fase:
		Fase.INVOCAR:
			_subidas = _mejor + 1
			_nivel = _mejor
			_estallar()
		Fase.ENTRADA:
			_terminar_entrada()
		Fase.VOLTEAR:
			# Todas boca arriba hasta la proxima de los tiers de arriba.
			while _siguiente < _resultados.size() and (_resultados[_siguiente].tier < 2 or _vistas.has(_siguiente)):
				_volteo[_siguiente] = _reloj - VUELTA
				_siguiente += 1
			_espera_carta = 0.0
		Fase.MOSTRAR:
			if _resultados.size() > 1:
				_seguir()


## Al final, sin mas cinematicas.
func _saltar() -> void:
	if _resultados.size() == 1:
		if _fase != Fase.ENTRADA and _fase != Fase.MOSTRAR:
			_empezar_revelacion(0)
		_terminar_entrada()
		return
	for i in _resultados.size():
		if _volteo[i] < 0.0:
			_volteo[i] = _reloj - VUELTA
	_siguiente = _resultados.size()
	_giro.visible = false
	_ir(Fase.RESUMEN)
	_mostrar_botones()


func _seguir() -> void:
	if _resultados.size() > 1 and _fase == Fase.MOSTRAR:
		# Vuelve a las cartas, con esa ya boca arriba.
		_volteo[_actual] = _reloj - VUELTA
		_siguiente = maxi(_siguiente, _actual + 1)
		_giro.visible = false
		_botones.visible = false
		_boton_saltar.visible = true
		_espera_carta = ENTRE_CARTAS
		_ir(Fase.VOLTEAR)
		return
	visible = false
	_giro.visible = false
	terminada.emit()


# --- Particulas y ondas -----------------------------------------------------------

func _onda(color: Color, fuerza: float) -> void:
	_ondas.append({"t": 0.0, "color": color, "fuerza": fuerza, "centro": _orbe() if _fase <= Fase.ESTALLIDO else _centro_objeto()})


func _subir_brillos(tier: int) -> void:
	if randf() < 0.5:
		var x := _centro_objeto().x + randf_range(-220.0, 220.0) * _escala
		_particulas.append({"p": Vector2(x, size.y + 10.0), "v": Vector2(randf_range(-20.0, 20.0), -randf_range(120.0, 260.0)) * _escala,
			"vida": 0.0, "max": 2.5, "color": _color_tier(tier).lightened(0.4), "r": randf_range(1.5, 3.5) * _escala, "tipo": "brillo"})


func _soltar_confeti() -> void:
	for i in 1:
		_particulas.append({"p": Vector2(randf() * size.x, -10.0), "v": Vector2(randf_range(-40.0, 40.0), randf_range(80.0, 160.0)) * _escala,
			"vida": 0.0, "max": 4.5, "color": _arcoiris(randf()), "r": randf_range(4.0, 7.0) * _escala, "tipo": "confeti",
			"giro": randf() * TAU})


func _mover_particulas(delta: float) -> void:
	for i in range(_particulas.size() - 1, -1, -1):
		var p := _particulas[i]
		p.vida += delta
		if p.tipo == "chispa" and p.has("hasta"):
			# Las que van al orbe se apagan al llegar.
			if p.p.distance_to(p.hasta) < 12.0 * _escala:
				p.vida = p.max
		elif p.tipo == "confeti":
			p.v.x += sin(_reloj * 3.0 + p.giro) * 40.0 * delta
		else:
			p.v *= 1.0 - minf(1.0, 2.2 * delta)
		if p.has("giro"):
			p.giro += delta * 6.0
		p.p += p.v * delta
		if p.vida >= p.max:
			_particulas.remove_at(i)
	for i in range(_ondas.size() - 1, -1, -1):
		_ondas[i].t += delta
		if _ondas[i].t > 0.8:
			_ondas.remove_at(i)


# --- Donde va cada cosa -----------------------------------------------------------

func _orbe() -> Vector2:
	return size * 0.5 + Vector2(0.0, -30.0 * _escala)


func _centro_objeto() -> Vector2:
	return size * 0.5 + Vector2(0.0, -50.0 * _escala)


func _rect_carta(i: int) -> Rect2:
	var carta := CARTA * _escala
	var hueco := HUECO * _escala
	var columnas := mini(5, _resultados.size())
	var filas := ceili(_resultados.size() / 5.0)
	var total := Vector2(columnas * carta.x + (columnas - 1) * hueco, filas * carta.y + (filas - 1) * hueco)
	var origen := size * 0.5 - total * 0.5 + Vector2(0.0, -24.0 * _escala)
	return Rect2(origen + Vector2((i % 5) * (carta.x + hueco), floori(i / 5.0) * (carta.y + hueco)), carta)


func _centro_carta(i: int) -> Vector2:
	return _rect_carta(i).get_center()


func _color_tier(tier: int) -> Color:
	return _tirada.colores[clampi(tier, 0, _tirada.colores.size() - 1)]


func _arcoiris(h: float) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), 0.7, 1.0)


# --- Dibujo -----------------------------------------------------------------------

func _draw() -> void:
	_lienzo = self
	_matriz = Transform2D(0.0, _desplazado)
	draw_rect(Rect2(Vector2.ZERO, size), FONDO)
	draw_set_transform_matrix(_matriz)
	match _fase:
		Fase.INVOCAR, Fase.ESTALLIDO:
			_pintar_invocacion()
		Fase.REPARTIR, Fase.VOLTEAR, Fase.RESUMEN:
			_pintar_cartas()
		Fase.ENTRADA, Fase.MOSTRAR:
			_pintar_revelacion()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pintar_encima() -> void:
	_lienzo = _encima
	_matriz = Transform2D(0.0, _desplazado)
	_encima.draw_set_transform_matrix(_matriz)
	if _fase == Fase.ENTRADA:
		var t := _t
		if _tier_actual() == 2:
			_pintar_franja(t, _color_tier(2))
			if t > 1.0 and t < 1.45:
				# La luz que barre la silueta, de izquierda a derecha.
				var centro := _centro_objeto()
				var x := centro.x + lerpf(-200.0, 200.0, (t - 1.0) / 0.45) * _escala
				_encima.draw_rect(Rect2(x - 14.0 * _escala, centro.y - 190.0 * _escala, 28.0 * _escala, 380.0 * _escala), Color(1.0, 1.0, 1.0, 0.55))
		elif _tier_actual() == 3:
			_pintar_sello_maximo(t)
	_pintar_ondas()
	_pintar_particulas()
	_encima.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _destello > 0.0:
		_encima.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, _destello))
	_lienzo = self


func _pintar_invocacion() -> void:
	var t := _t if _fase == Fase.INVOCAR else _duracion_invocar()
	var u := clampf(t / _duracion_invocar(), 0.0, 1.0)
	var color := _color_tier(_nivel)
	var o := _orbe()
	# Circulo de runas en el suelo, en perspectiva (un circulo aplastado).
	var suelo := o + Vector2(0.0, 175.0 * _escala)
	var aparece := clampf(t / 0.4, 0.0, 1.0)
	draw_set_transform(suelo + _desplazado, 0.0, Vector2(1.0, 0.28))
	for k in 3:
		var radio := (230.0 - k * 34.0) * _escala
		draw_arc(Vector2.ZERO, radio, 0.0, TAU, 64, Color(color, 0.55 * aparece), (3.0 - k * 0.6) * _escala, true)
	for k in 16:
		var angulo := k * TAU / 16.0 + _reloj * 0.6
		var p := Vector2.from_angle(angulo) * 212.0 * _escala
		_pintar_runa(p, angulo, 9.0 * _escala, Color(color.lightened(0.4), 0.8 * aparece))
	draw_set_transform(_desplazado, 0.0, Vector2.ONE)
	# Columna de luz del circulo al orbe.
	var ancho := 70.0 * _escala * (0.6 + 0.4 * u)
	draw_polygon(PackedVector2Array([suelo + Vector2(-ancho, 0.0), suelo + Vector2(ancho, 0.0), o + Vector2(ancho * 0.3, 0.0), o + Vector2(-ancho * 0.3, 0.0)]),
		PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, 0.25 * aparece), Color(color, 0.25 * aparece)]))
	# Los rayos que caen (antes del tercer tier).
	for rayo in _rayos:
		var edad: float = _t - rayo.t
		if edad >= 0.0 and edad < 0.3 and int(edad * 30.0) % 2 == 0:
			_pintar_rayo(Vector2(o.x + (rayo.semilla % 200 - 100) * _escala, 0.0), o, rayo.semilla, color.lightened(0.5))
	if _fase == Fase.ESTALLIDO:
		return
	# El orbe: crece, late y brilla.
	var radio := lerpf(10.0, 56.0, u * u) * _escala * (1.0 + 0.07 * sin(_reloj * 14.0))
	for k in 8:
		draw_circle(o, radio * (2.6 - k * 0.2), Color(color, 0.05))
	draw_circle(o, radio, color)
	draw_circle(o, radio * 0.7, color.lightened(0.5))
	draw_circle(o, radio * 0.4, Color.WHITE)
	# Las grietas de arcoiris (antes del tier mas alto).
	if _grieta_desde >= 0.0:
		var crece := clampf((_t - _grieta_desde) / 0.45, 0.0, 1.0)
		for k in 7:
			var angulo := k * TAU / 7.0 + 0.4
			var largo := radio * (0.8 + 0.5 * ((k * 37) % 10) / 10.0) * crece
			var codo := o + Vector2.from_angle(angulo) * largo * 0.55 + Vector2.from_angle(angulo + 1.2) * radio * 0.12
			var punta := o + Vector2.from_angle(angulo) * largo
			var tono := _arcoiris(k / 7.0 + _reloj * 0.5)
			draw_polyline(PackedVector2Array([o, codo, punta]), Color(tono, 0.5), 7.0 * _escala, true)
			draw_polyline(PackedVector2Array([o, codo, punta]), Color.WHITE, 2.0 * _escala, true)


func _pintar_runa(p: Vector2, angulo: float, r: float, color: Color) -> void:
	var giro := Transform2D(angulo + PI * 0.5, p)
	var trazo := [Vector2(-0.6, -0.8), Vector2(0.0, 0.8), Vector2(0.6, -0.8)]
	var puntos := PackedVector2Array()
	for q: Vector2 in trazo:
		puntos.append(giro * (q * r))
	draw_polyline(puntos, color, 2.0 * _escala, true)
	draw_line(giro * (Vector2(-0.45, -0.1) * r), giro * (Vector2(0.45, -0.1) * r), color, 2.0 * _escala, true)


func _pintar_rayo(desde: Vector2, hasta: Vector2, semilla: int, color: Color) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var puntos := PackedVector2Array([desde])
	for k in range(1, 9):
		var p := desde.lerp(hasta, k / 9.0)
		puntos.append(p + Vector2(azar.randf_range(-30.0, 30.0) * _escala, 0.0))
	puntos.append(hasta)
	draw_polyline(puntos, Color(color, 0.35), 14.0 * _escala, true)
	draw_polyline(puntos, color, 5.0 * _escala, true)
	draw_polyline(puntos, Color.WHITE, 2.0 * _escala, true)


func _pintar_ondas() -> void:
	for onda in _ondas:
		var u: float = onda.t / 0.8
		var radio: float = (30.0 + 380.0 * onda.fuerza * (1.0 - pow(1.0 - u, 2.0))) * _escala
		_lienzo.draw_arc(onda.centro, radio, 0.0, TAU, 72, Color(onda.color, 0.7 * (1.0 - u)), (10.0 * (1.0 - u) + 1.0) * _escala, true)


func _pintar_particulas() -> void:
	for p in _particulas:
		var vida: float = 1.0 - p.vida / p.max
		var color: Color = p.color
		match p.tipo:
			"chispa":
				var cola: Vector2 = p.v * 0.03
				_lienzo.draw_line(p.p - cola, p.p, Color(color, vida), p.r, true)
				_lienzo.draw_circle(p.p, p.r * 0.7, Color(Color.WHITE, vida))
			"brillo":
				_lienzo.draw_circle(p.p, p.r * 2.4, Color(color, 0.18 * vida))
				_lienzo.draw_circle(p.p, p.r, Color(color, vida))
			"esquirla":
				var forma := PackedVector2Array()
				for k in 3:
					forma.append(p.p + Vector2.from_angle(p.giro + k * TAU / 3.0) * p.r * (2.6 if k == 0 else 1.4))
				_lienzo.draw_colored_polygon(forma, Color(color, vida))
			"confeti":
				var giro := Transform2D(p.giro, p.p)
				var ancho: float = p.r * absf(cos(p.giro * 0.7))
				_lienzo.draw_colored_polygon(PackedVector2Array([giro * Vector2(-ancho, -p.r * 0.5), giro * Vector2(ancho, -p.r * 0.5),
					giro * Vector2(ancho, p.r * 0.5), giro * Vector2(-ancho, p.r * 0.5)]), Color(color, minf(1.0, vida * 3.0)))


func _pintar_rayos_fondo(centro: Vector2, color: Color, cuantos: int, alfa: float, arcoiris: bool) -> void:
	var largo := size.length()
	for i in cuantos:
		var angulo := i * TAU / cuantos + _reloj * 0.25
		var tono := _arcoiris(float(i) / cuantos + _reloj * 0.1) if arcoiris else color
		draw_colored_polygon(PackedVector2Array([centro, centro + Vector2.from_angle(angulo - 0.07) * largo,
			centro + Vector2.from_angle(angulo + 0.07) * largo]), Color(tono, alfa))


## Estrellas que salen del centro como a la velocidad de la luz (la S+).
func _pintar_hiperespacio(centro: Vector2, fuerza: float) -> void:
	var lejos := size.length() * 0.6
	for i in 110:
		var angulo := fposmod(i * 2.399, TAU)
		var rapidez := 0.35 + 0.65 * fposmod(i * 0.618, 1.0)
		var r := fposmod(i * 37.0 + _reloj * 900.0 * rapidez, lejos)
		var desde := centro + Vector2.from_angle(angulo) * r
		var hasta := centro + Vector2.from_angle(angulo) * (r + (12.0 + r * 0.18) * rapidez)
		draw_line(desde, hasta, Color(_arcoiris(float(i) / 110.0 + _reloj * 0.2), fuerza * clampf(r / 120.0, 0.0, 1.0)), 2.0 * _escala, true)


func _pintar_revelacion() -> void:
	var resultado := _resultados[_actual]
	var tier: int = resultado.tier
	var color := _color_tier(tier)
	var centro := _centro_objeto()
	var t := _t if _fase == Fase.ENTRADA else 99.0
	if tier == 3:
		_pintar_hiperespacio(centro, 0.9)
		_pintar_rayos_fondo(centro, color, 18, 0.07, true)
	elif tier == 2:
		if t > 0.6:
			_pintar_rayos_fondo(centro, color, 14, 0.1 * clampf((t - 0.6) / 0.4, 0.0, 1.0), false)
	else:
		_pintar_rayos_fondo(centro, color, 12, 0.08, false)
	draw_circle(centro, 190.0 * _escala, Color(color, 0.08))
	# Los textos: el tier arriba y el nombre debajo (en las de arriba, letra a letra).
	var desde_nombre := 0.0
	match tier:
		2:
			desde_nombre = 1.35
		3:
			desde_nombre = 1.9
	if t >= desde_nombre or tier < 2:
		var etiqueta: String = _tirada.tiers[tier].to_upper()
		var arriba := centro + Vector2(0.0, -205.0 * _escala)
		if tier == 3:
			_texto_corrido(arriba, etiqueta, 54, 4.0)
		else:
			_texto(arriba, etiqueta, 50, color)
	if t < desde_nombre:
		return
	var objeto: Resource = resultado.objeto
	var nombre: String = objeto.nombre
	var letras := nombre.length() if tier < 2 else mini(nombre.length(), int((t - desde_nombre) * LETRAS))
	var y := centro.y + 200.0 * _escala
	_texto(Vector2(centro.x, y), nombre.substr(0, letras), 34, _arcoiris(_reloj * 0.3) if tier == 3 else Color.WHITE)
	if letras < nombre.length():
		return
	var debajo: String = objeto.mago if objeto is SkinMago else objeto.descripcion
	_texto(Vector2(centro.x, y + 32.0 * _escala), debajo, 17, Color(0.85, 0.82, 0.78))
	var resultado_texto := "¡NUEVA!" if resultado.nuevo else "Ya la tenías: ganas %d %s" % [resultado.devuelto, _tirada.moneda()]
	var pulso := 0.8 + 0.2 * sin(_reloj * 6.0)
	_texto(Vector2(centro.x, y + 62.0 * _escala), resultado_texto, 22 if resultado.nuevo else 16,
		Color(1.0, 0.82, 0.3, pulso) if resultado.nuevo else Color(0.65, 0.62, 0.6))
	if resultado.get("garantizada", false):
		_texto(Vector2(centro.x, y - 34.0 * _escala), "¡Garantizada!", 16, Color(1.0, 0.82, 0.3))


## La S (o la legendaria): una franja de su color entra de lado y el sello cae.
func _pintar_franja(t: float, color: Color) -> void:
	var centro := _centro_objeto()
	var entra := clampf(t / 0.3, 0.0, 1.0)
	var sale := clampf((t - 0.95) / 0.3, 0.0, 1.0)
	if sale >= 1.0:
		return
	var alto := 150.0 * _escala * (1.0 - sale)
	var inclinacion := 60.0 * _escala
	var x0 := -size.x + size.x * 2.0 * (1.0 - pow(1.0 - entra, 3.0))
	_lienzo.draw_colored_polygon(PackedVector2Array([Vector2(x0 - size.x, centro.y - alto * 0.5 + inclinacion), Vector2(x0 + size.x, centro.y - alto * 0.5 - inclinacion),
		Vector2(x0 + size.x, centro.y + alto * 0.5 - inclinacion), Vector2(x0 - size.x, centro.y + alto * 0.5 + inclinacion)]), Color(color, 0.85))
	if t >= 0.2:
		var cae := clampf((t - 0.2) / 0.18, 0.0, 1.0)
		var escala := lerpf(3.0, 1.0, cae * cae)
		_texto(centro, _tirada.tiers[2].to_upper(), 96 if _tirada.tiers[2].length() <= 2 else 64, Color.WHITE, escala, 10)


## La S+ (o la mitica): la primera letra cae, luego el resto, con los colores
## corridos como en una pantalla que falla. Luego sube y se va.
func _pintar_sello_maximo(t: float) -> void:
	var centro := _centro_objeto()
	var nombre: String = _tirada.tiers[3].to_upper()
	var primera := nombre.substr(0, 1) if nombre.ends_with("+") else nombre
	var resto := "+" if nombre.ends_with("+") else ""
	var sube := clampf((t - 1.05) / 0.4, 0.0, 1.0)
	var alfa := 1.0 - sube
	if alfa <= 0.0:
		return
	var y := centro.y - 160.0 * _escala * sube
	if t >= 0.35:
		var cae := clampf((t - 0.35) / 0.2, 0.0, 1.0)
		var x := centro.x - (40.0 * _escala if resto != "" else 0.0)
		_texto_corrido(Vector2(x, y), primera, 150 if primera.length() <= 2 else 70, 8.0, lerpf(3.2, 1.0, cae * cae), alfa)
	if resto != "" and t >= 0.7:
		var cae := clampf((t - 0.7) / 0.15, 0.0, 1.0)
		_texto_corrido(Vector2(centro.x + 70.0 * _escala, y - 10.0 * _escala), resto, 120, 8.0, lerpf(3.5, 1.0, cae * cae), alfa)


func _pintar_cartas() -> void:
	for i in _resultados.size():
		var rect := _rect_carta(i)
		var tier: int = _resultados[i].tier
		var color := _color_tier(tier)
		if _fase == Fase.REPARTIR:
			# Los diez orbes van del centro a su carta.
			var u := clampf(_t / REPARTIR - i * 0.03, 0.0, 1.0)
			var p := _orbe().lerp(rect.get_center(), 1.0 - pow(1.0 - u, 3.0))
			draw_circle(p, 22.0 * _escala, Color(color, 0.25))
			draw_circle(p, 10.0 * _escala, color.lightened(0.4))
			continue
		var inicio := _volteo[i]
		var vuelta := clampf((_reloj - inicio) / VUELTA, 0.0, 1.0) if inicio >= 0.0 else 0.0
		var ancho := absf(cos(vuelta * PI))
		var temblor := Vector2.ZERO
		if i == _avisando:
			temblor = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 6.0 * _escala * (_t / AVISO_CARTA)
			draw_circle(rect.get_center(), 130.0 * _escala * (_t / AVISO_CARTA), Color(color if tier < 3 else _arcoiris(_reloj), 0.2))
		_matriz = Transform2D(0.0, Vector2(maxf(ancho, 0.02), 1.0), 0.0, rect.get_center() + temblor + _desplazado)
		draw_set_transform_matrix(_matriz)
		var local := Rect2(-rect.size * 0.5, rect.size)
		if vuelta < 0.5:
			_pintar_dorso(local, color, tier, i == _avisando)
		else:
			_pintar_cara(local, _resultados[i])
		_matriz = Transform2D(0.0, _desplazado)
		draw_set_transform_matrix(_matriz)
	if _fase == Fase.RESUMEN:
		var nuevas := 0
		var devuelto := 0
		for resultado in _resultados:
			nuevas += 1 if resultado.nuevo else 0
			devuelto += resultado.devuelto
		var texto := "%d nuevas" % nuevas if nuevas != 1 else "1 nueva"
		if devuelto > 0:
			texto += " · lo repetido te da %d %s" % [devuelto, _tirada.moneda()]
		_texto(Vector2(size.x * 0.5, _rect_carta(0).position.y - 26.0 * _escala), texto, 20, Color(1.0, 0.82, 0.3))


func _pintar_dorso(rect: Rect2, color: Color, tier: int, avisando: bool) -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = color.darkened(0.75)
	caja.border_color = color if tier < 3 or not avisando else _arcoiris(_reloj)
	caja.set_border_width_all(int(4.0 * _escala))
	caja.set_corner_radius_all(int(10.0 * _escala))
	caja.shadow_color = Color(color, 0.5)
	caja.shadow_size = int((8.0 + 4.0 * tier) * _escala)
	draw_style_box(caja, rect)
	var c := rect.get_center()
	draw_arc(c, rect.size.x * 0.3, 0.0, TAU, 32, Color(color, 0.8), 2.5 * _escala, true)
	draw_arc(c, rect.size.x * 0.22, 0.0, TAU, 32, Color(color, 0.5), 1.5 * _escala, true)
	for k in 8:
		var angulo := k * TAU / 8.0 + _reloj * 0.8
		draw_circle(c + Vector2.from_angle(angulo) * rect.size.x * 0.3, 2.5 * _escala, color.lightened(0.4))
	draw_circle(c, rect.size.x * 0.08, color.lightened(0.5))


func _pintar_cara(rect: Rect2, resultado: Dictionary) -> void:
	var tier: int = resultado.tier
	var color := _color_tier(tier)
	var caja := StyleBoxFlat.new()
	caja.bg_color = color.darkened(0.82)
	caja.border_color = color if tier < 3 else _arcoiris(_reloj * 0.3)
	caja.set_border_width_all(int(4.0 * _escala))
	caja.set_corner_radius_all(int(10.0 * _escala))
	caja.shadow_color = Color(color, 0.35)
	caja.shadow_size = int(6.0 * _escala)
	draw_style_box(caja, rect)
	var objeto: Resource = resultado.objeto
	var imagen: Texture2D = objeto.retrato if objeto is SkinMago else (objeto.ilustracion if objeto.ilustracion != null else objeto.icono)
	var zona := Rect2(rect.position + Vector2(10.0, 24.0) * _escala, Vector2(rect.size.x - 20.0 * _escala, rect.size.y - 70.0 * _escala))
	var medida := imagen.get_size() * minf(zona.size.x / imagen.get_width(), zona.size.y / imagen.get_height())
	draw_texture_rect(imagen, Rect2(zona.get_center() - medida * 0.5, medida), false)
	_texto(rect.position + Vector2(18.0, 16.0) * _escala, _tirada.tiers[tier], 15, color, 1.0, 4, false)
	_texto(Vector2(rect.get_center().x, rect.end.y - 32.0 * _escala), objeto.nombre, 14, Color.WHITE)
	if resultado.nuevo:
		_texto(Vector2(rect.get_center().x, rect.end.y - 13.0 * _escala), "¡NUEVA!", 13, Color(1.0, 0.82, 0.3))
	else:
		_texto(Vector2(rect.get_center().x, rect.end.y - 13.0 * _escala), "+%d" % resultado.devuelto, 12, Color(0.65, 0.62, 0.6))


## Un texto centrado en 'centro', con borde oscuro. 'tamano' es a 1152 x 648.
func _texto(centro: Vector2, texto: String, tamano: int, color: Color, escala: float = 1.0, contorno: int = 6,
		centrado: bool = true) -> void:
	var fuente := get_theme_default_font()
	var letra := maxi(8, int(tamano * _escala))
	var medida := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, letra)
	var esquina := Vector2(-medida.x * 0.5 if centrado else 0.0, letra * 0.36)
	_lienzo.draw_set_transform_matrix(_matriz * Transform2D(0.0, Vector2.ONE * escala, 0.0, centro))
	if contorno > 0:
		_lienzo.draw_string_outline(fuente, esquina, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, letra, int(contorno * _escala) + 1,
			Color(0.0, 0.0, 0.0, 0.85 * color.a))
	_lienzo.draw_string(fuente, esquina, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, letra, color)
	_lienzo.draw_set_transform_matrix(_matriz)


## El texto con el rojo y el azul corridos a los lados, y arcoiris encima.
func _texto_corrido(centro: Vector2, texto: String, tamano: int, corrido: float, escala: float = 1.0, alfa: float = 1.0) -> void:
	var d := Vector2(corrido * _escala * (1.0 + 0.4 * sin(_reloj * 20.0)), 0.0)
	_texto(centro - d, texto, tamano, Color(1.0, 0.15, 0.3, 0.7 * alfa), escala, 0)
	_texto(centro + d, texto, tamano, Color(0.15, 0.8, 1.0, 0.7 * alfa), escala, 0)
	_texto(centro, texto, tamano, Color(_arcoiris(_reloj * 0.4).lightened(0.35), alfa), escala, 8)
