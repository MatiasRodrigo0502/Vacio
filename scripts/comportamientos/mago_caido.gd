## El Mago Caido, el jefe del piso 12: el cuarto mago, el que bajo antes que
## tu y se lo trago el vacio. Pedido por Matias el 2026-10-14: «que tenga las
## habilidades de los otros magos y que dispare rayos en vez de bolas».
##
## Dispara rayos (su proyectil, con la linea de aviso de siempre) y, cada
## pocos segundos, usa una de las habilidades de los otros tres magos. Cuantas
## sabe depende de la fase, que va por la vida que le queda:
##
## 1. Del 100 al 66 %: el AGUJERO NEGRO del mago oscuro, al reves: se abre
##    donde estas y tira de ti (PozoVacio). Mientras crece no tira: es el aviso.
## 2. Del 66 al 33 %: ademas, el ESCUDO del mago blanco: una burbuja en la que
##    tus disparos no le hacen nada, y mientras la tiene suelta anillos de
##    esquirlas de hielo que frenan, como el disparo del blanco.
## 3. Del 33 % al final: ademas, el ATAQUE CARGADO del mago rojo: carga un
##    rayo de fuego enorme (su linea avisa y se queda quieta al final) que deja
##    fuego por donde pasa. Un pilar lo para, pero se rompe (Matias,
##    2026-10-14): cada pilar sirve una vez. Y los rayos salen de tres en
##    tres, mas deprisa.
##
## Negro y oro, con una guadana (generar_mago_caido.py): la primera version
## era violeta y se confundia con el mago oscuro. Sus efectos van en oro.
##
## Al cambiar de fase se va al centro, se protege, suelta una onda y deja un
## vendaje: un respiro, y el aviso de que ahora viene mas.
##
## No hace nada hasta que se cierran las puertas de su sala, y luego espera a
## que acabe la presentacion (BarraJefe). Hasta entonces no se le puede dar:
## sin eso, desde el umbral se le podia quitar vida sin pelear.
##
## Todos los numeros estan en su .tres (resources/jefes/mago_caido.tres).
class_name ComportamientoMagoCaido
extends ComportamientoEnemigo

## Las ocho direcciones de las animaciones del mago, en el orden de los
## angulos (como Jugador.LADOS).
const LADOS: Array[StringName] = [
	&"derecha", &"abajo_derecha", &"abajo", &"abajo_izquierda",
	&"izquierda", &"arriba_izquierda", &"arriba", &"arriba_derecha",
]
## Su color: el de sus ojos, el ribete y el filo de la guadana.
const COLOR_ORO := Color(1.0, 0.8, 0.28)
const COLOR_HIELO := Color(0.7, 0.92, 1.0)
const COLOR_FUEGO := Color(1.0, 0.55, 0.15)

## Segundos desde que se cierran las puertas hasta que empieza a pelear: lo
## que dura su presentacion.
@export var presentacion: float = 2.2
## Vida (de 0 a 1) a la que pasa a la fase 2 y a la 3.
@export var paso_fase_2: float = 0.66
@export var paso_fase_3: float = 0.33
## Todo va a este ritmo en cada fase (moverse, apuntar, recargar): 1 = el de
## su .tres.
@export var ritmo_fases: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.35])
## Segundos entre una habilidad y la siguiente (a su ritmo).
@export var espera_habilidad: float = 5.0

@export_group("Agujero negro")
@export var radio_pozo: float = 170.0
@export var duracion_pozo: float = 3.4
## Lo que tarda en tirar desde que aparece: el aviso.
@export var aviso_pozo: float = 0.9
@export var dano_pozo: int = 15

@export_group("Escudo")
@export var duracion_escudo: float = 4.0
## Lo que suelta mientras tiene el escudo: esquirlas de hielo que frenan.
@export var esquirla: TipoProyectil
@export var esquirlas_por_anillo: int = 10
@export var cada_anillo: float = 1.1

@export_group("Rayo de fuego")
## Lo que carga. Los ultimos 'fija_fuego' segundos la linea ya no te sigue:
## ahi es cuando hay que apartarse.
@export var carga_fuego: float = 1.4
@export var fija_fuego: float = 0.45
@export var ancho_fuego: float = 46.0
@export var dano_fuego: int = 50
## Charcos de fuego que deja por donde pasa, y como son.
@export var charcos_fuego: int = 5
@export var radio_charco: float = 30.0
@export var duracion_charco: float = 3.0

@export_group("Rayos de tres en tres (fase 3)")
## Grados entre el rayo del centro y los de los lados.
@export var abertura_abanico: float = 16.0

@export_group("Cambio de fase")
@export var duracion_cambio: float = 1.6
@export var radio_onda: float = 300.0
@export var dano_onda: int = 25
## Lo que deja al cambiar de fase para recuperarse (el vendaje).
@export var cura: ObjetoMejora

## Lo que dura el rayo de fuego en pantalla una vez sale.
const DURACION_FUEGO: float = 0.4
## Lo que tarda en irse y en volver al teletransportarse al centro.
const DESVANECER: float = 0.35
const DURACION_DESTELLO: float = 0.2


func empezar(enemigo: Enemigo) -> void:
	super.empezar(enemigo)
	enemigo.estado["accion"] = &"esperando"
	enemigo.estado["t"] = 0.0
	enemigo.estado["fase"] = 1
	enemigo.estado["habilidad"] = espera_habilidad * 0.6
	enemigo.estado["siguiente"] = 0
	enemigo.estado["vistos"] = enemigo.disparos
	enemigo.estado["destello"] = 0.0
	enemigo.estado["vida_fase"] = 1.0
	enemigo.animar(&"quieto_abajo")


func procesar(enemigo: Enemigo, delta: float) -> void:
	var e := enemigo.estado
	e["t"] = float(e["t"]) + delta
	e["destello"] = maxf(0.0, float(e["destello"]) - delta)
	var t: float = e["t"]
	var hacia := enemigo.hacia_objetivo()
	match e["accion"]:
		&"esperando":
			_mirar(enemigo, hacia, false)
			var sala := enemigo.sala()
			if sala != null and sala.esta_cerrada():
				_pasar(enemigo, &"presentacion")
		&"presentacion":
			_mirar(enemigo, hacia, false)
			if t >= presentacion:
				_pasar(enemigo, &"pelea")
		&"pelea":
			_pelear(enemigo, delta, hacia)
		&"pozo":
			_mirar(enemigo, hacia, false)
			enemigo.brillo(t / 0.5)
			if t >= 0.5:
				enemigo.brillo(0.0)
				_abrir_pozo(enemigo)
				_pasar(enemigo, &"pelea")
		&"escudo":
			_mirar(enemigo, hacia, false)
			var anillos := int(t / cada_anillo)
			if anillos > int(e.get("anillos", 0)) and t < duracion_escudo:
				e["anillos"] = anillos
				_anillo_de_hielo(enemigo, anillos)
			if t >= duracion_escudo:
				_pasar(enemigo, &"pelea")
		&"cargando":
			# La linea te sigue hasta los ultimos 'fija_fuego' segundos.
			if t < carga_fuego - fija_fuego:
				e["dir"] = hacia.normalized() if hacia.length() > 1.0 else Vector2.DOWN
			_mirar(enemigo, e["dir"], false)
			var linea := _linea(enemigo, e["dir"])
			e["largo"] = linea["largo"]
			e["pilar"] = linea["pilar"]
			enemigo.brillo(t / carga_fuego)
			if t >= carga_fuego:
				enemigo.brillo(0.0)
				_soltar_fuego(enemigo)
				_pasar(enemigo, &"fuego")
		&"fuego":
			if t >= DURACION_FUEGO:
				_pasar(enemigo, &"pelea")
		&"cambio":
			_cambiar_de_fase(enemigo, t)


## Lo normal: a su distancia, rayos con aviso y, de vez en cuando, una
## habilidad. Y si la vida ha bajado del paso de fase, a cambiar.
func _pelear(enemigo: Enemigo, delta: float, hacia: Vector2) -> void:
	var e := enemigo.estado
	var fase: int = e["fase"]
	if (fase == 1 and enemigo.fraccion_vida() <= paso_fase_2) \
			or (fase == 2 and enemigo.fraccion_vida() <= paso_fase_3):
		_pasar(enemigo, &"cambio")
		enemigo.sonar(&"teletransporte")
		return
	var ritmo := ritmo_fases[clampi(fase - 1, 0, ritmo_fases.size() - 1)]
	var antes := enemigo.global_position
	enemigo.pelear_a_distancia(delta * ritmo, hacia, hacia.length())
	_mirar(enemigo, hacia, enemigo.global_position.distance_to(antes) > 0.3)
	# En la fase 3, cada rayo sale con dos mas a los lados.
	if enemigo.disparos > int(e["vistos"]):
		e["vistos"] = enemigo.disparos
		if fase >= 3:
			var centro := hacia.normalized()
			for lado in [-1.0, 1.0]:
				enemigo.disparar_hacia(centro.rotated(deg_to_rad(abertura_abanico) * lado))
	e["habilidad"] = float(e["habilidad"]) - delta * ritmo
	if float(e["habilidad"]) <= 0.0 and not enemigo.esta_apuntando():
		e["habilidad"] = espera_habilidad
		_usar_habilidad(enemigo)


## Las habilidades que sabe en cada fase, por turnos: en la 3, el fuego sale
## una de cada dos veces.
func _usar_habilidad(enemigo: Enemigo) -> void:
	var e := enemigo.estado
	var turnos: Array[StringName] = [&"pozo"]
	match int(e["fase"]):
		2:
			turnos = [&"escudo", &"pozo"]
		3:
			turnos = [&"cargando", &"pozo", &"cargando", &"escudo"]
	var cual: StringName = turnos[int(e["siguiente"]) % turnos.size()]
	e["siguiente"] = int(e["siguiente"]) + 1
	_pasar(enemigo, cual)
	match cual:
		&"pozo":
			enemigo.sonar(&"carga_lista")
		&"escudo":
			e["anillos"] = 0
			enemigo.sonar(&"escudo")
		&"cargando":
			e["dir"] = enemigo.hacia_objetivo().normalized()
			enemigo.sonar(&"carga_lista")


## Se abre donde esta a quien persigue (en cooperativo, el mas cercano). Por
## MundoRed: sale en todos los ordenadores y tira del jugador de cada uno.
func _abrir_pozo(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	var suelo := sala.rect_suelo_global().grow(-PozoVacio.NUCLEO)
	var donde := (enemigo.global_position + enemigo.hacia_objetivo()).clamp(suelo.position, suelo.end)
	MundoRed.crear_pozo(sala, donde, duracion_pozo, radio_pozo, float(dano_pozo),
		COLOR_ORO, Color(0.55, 0.36, 0.06), aviso_pozo)


## Un anillo de esquirlas alrededor. Cada anillo girado medio hueco respecto
## al anterior: asi el sitio seguro cambia y hay que moverse.
func _anillo_de_hielo(enemigo: Enemigo, numero: int) -> void:
	if esquirla == null or esquirlas_por_anillo <= 0:
		return
	var giro := (numero % 2) * PI / esquirlas_por_anillo
	for i in esquirlas_por_anillo:
		enemigo.disparar_hacia(Vector2.RIGHT.rotated(giro + i * TAU / esquirlas_por_anillo), esquirla)


## Sale el rayo de fuego: quita vida si el jugador esta en la linea (hasta la
## primera roca o muro) y deja charcos de fuego por el camino.
func _soltar_fuego(enemigo: Enemigo) -> void:
	var e := enemigo.estado
	var dir: Vector2 = e["dir"]
	var largo: float = e["largo"]
	var desde := enemigo.global_position
	var hasta := desde + dir * largo
	# Si lo ha parado un pilar, el pilar se rompe.
	var pilar: Variant = e.get("pilar")
	if pilar is Obstaculo and is_instance_valid(pilar):
		_romper_pilar(enemigo, pilar)
	# A cada jugador en la linea: por MundoRed, en cooperativo cada ordenador
	# mira el suyo.
	MundoRed.fuego(desde, hasta, ancho_fuego, dano_fuego, "Mago caído (rayo de fuego)")
	var sala := enemigo.sala()
	if sala == null or charcos_fuego <= 0:
		return
	var objetivo := enemigo.global_position + enemigo.hacia_objetivo()
	for i in charcos_fuego:
		var punto := desde.lerp(hasta, (i + 1.0) / (charcos_fuego + 1.0))
		# Uno justo debajo del jugador seria un segundo golpe sin aviso.
		if punto.distance_to(objetivo) < radio_charco + 30.0:
			continue
		MundoRed.crear_lava(sala, sala.to_local(punto), radio_charco, duracion_charco,
			"Mago caído (fuego)")


## Rompe el pilar que ha parado el rayo de fuego: se quita (y la sala lo
## olvida, para no seguir apartando a nadie de donde estaba) y saltan sus
## trozos.
func _romper_pilar(enemigo: Enemigo, pilar: Obstaculo) -> void:
	var sala := enemigo.sala()
	if sala != null:
		MundoRed.romper_pilar(sala, pilar)
	else:
		pilar.romper()


## El cambio de fase: se desvanece, aparece en el centro, suelta la onda y
## el corazon, y vuelve a pelear con lo nuevo.
func _cambiar_de_fase(enemigo: Enemigo, t: float) -> void:
	var e := enemigo.estado
	var sala := enemigo.sala()
	if t < DESVANECER:
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0 - t / DESVANECER)
	elif not e.get("en_el_centro", false):
		e["en_el_centro"] = true
		if sala != null:
			enemigo.global_position = sala.global_position
	elif t < DESVANECER * 2.0:
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, (t - DESVANECER) / DESVANECER)
	elif not e.get("onda", false):
		e["onda"] = true
		enemigo.poner_sprite(Vector2.ZERO, Vector2.ONE, 1.0)
		_soltar_onda(enemigo)
	if t >= duracion_cambio:
		e["fase"] = int(e["fase"]) + 1
		e["habilidad"] = espera_habilidad * 0.5
		e.erase("en_el_centro")
		e.erase("onda")
		_pasar(enemigo, &"pelea")


func _soltar_onda(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala == null:
		return
	MundoRed.crear_onda(sala, sala.to_local(enemigo.global_position + Vector2(0.0, enemigo.tipo.alto * 0.42)),
		radio_onda, 0.6, dano_onda, COLOR_ORO, "Mago caído (onda)")
	# Un vendaje debajo del centro: lejos de los pilares y de la bajada.
	if cura != null:
		MundoRed.soltar_objeto(sala, cura, sala.to_global(Vector2(0.0, minf(sala.tamano.y * 0.32, 160.0))))


## Mira al jugador: anda o se queda quieto en la direccion que toca.
func _mirar(enemigo: Enemigo, hacia: Vector2, andando: bool) -> void:
	var lado := LADOS[posmod(int(roundf(hacia.angle() / (TAU / 8.0))), 8)]
	enemigo.animar(StringName(("caminar_" if andando else "quieto_") + lado))


func _pasar(enemigo: Enemigo, accion: StringName) -> void:
	enemigo.estado["accion"] = accion
	enemigo.estado["t"] = 0.0


## Hasta donde llega el rayo de fuego ("largo"): la primera roca o muro. Y si
## lo para un pilar, cual ("pilar"; si no, null): al soltarlo, se rompe.
func _linea(enemigo: Enemigo, dir: Vector2) -> Dictionary:
	var maximo := 2000.0
	var rayo := PhysicsRayQueryParameters2D.create(enemigo.global_position,
		enemigo.global_position + dir * maximo, Terreno.CAPA_MUROS | Terreno.CAPA_ROCAS)
	var golpe := enemigo.get_world_2d().direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return {"largo": maximo, "pilar": null}
	var pilar: Variant = golpe["collider"] if golpe["collider"] is Obstaculo else null
	return {"largo": enemigo.global_position.distance_to(golpe["position"]), "pilar": pilar}


func invulnerable(enemigo: Enemigo) -> bool:
	return enemigo.estado.get("accion", &"esperando") in [&"esperando", &"presentacion", &"escudo", &"cambio"]


func bloqueado(enemigo: Enemigo) -> void:
	enemigo.estado["destello"] = DURACION_DESTELLO
	enemigo.sonar(&"escudo_golpe")


func voltear(_enemigo: Enemigo) -> bool:
	return false


func marcas_vida() -> PackedFloat32Array:
	return PackedFloat32Array([paso_fase_2, paso_fase_3])


## Su final: una explosion grande del color del vacio y el juego a camara
## lenta un momento. La bajada se abre sola al morir (la sala se queda sin
## enemigos).
func al_morir(enemigo: Enemigo) -> void:
	var sala := enemigo.sala()
	if sala != null:
		for capa in [[260.0, COLOR_ORO], [150.0, Color(1.0, 0.97, 0.85)]]:
			var explosion := Explosion.new()
			explosion.radio = capa[0]
			explosion.color = capa[1]
			explosion.position = sala.to_local(enemigo.global_position)
			sala.add_child(explosion)
	Sonido.tocar(&"explosion")
	# A camara lenta un segundo de verdad (el temporizador no va a camara
	# lenta). Del arbol y no del enemigo, que se libera ya: asi vuelve a la
	# velocidad normal pase lo que pase.
	Engine.time_scale = 0.3
	enemigo.get_tree().create_timer(1.0, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


func dibujar(enemigo: Enemigo) -> void:
	var e := enemigo.estado
	var accion: StringName = e.get("accion", &"esperando")
	# Para lo que se mueve solo (el aura, el brillo del escudo).
	var fase := Time.get_ticks_msec() * 0.001
	var alto := enemigo.tipo.alto
	var pies := Vector2(0.0, alto * 0.42)
	# El aura: una sombra negra a los pies, con un aro de oro que late.
	enemigo.draw_set_transform(pies, 0.0, Vector2(1.0, 0.4))
	enemigo.draw_circle(Vector2.ZERO, alto * 0.55, Color(0.04, 0.03, 0.02, 0.45 + 0.1 * sin(fase * 3.0)))
	enemigo.draw_arc(Vector2.ZERO, alto * 0.55, 0.0, TAU, 40, Color(COLOR_ORO, 0.45 + 0.15 * sin(fase * 3.0)), 2.0, true)
	enemigo.draw_set_transform(Vector2.ZERO)
	# Chispas de oro que suben desde el aura.
	for k in 6:
		var avance := fposmod(fase * 0.5 + k / 6.0, 1.0)
		var x := sin(k * 2.3) * alto * 0.4
		var y := pies.y - avance * alto * 0.9
		enemigo.draw_circle(Vector2(x + sin(fase * 2.0 + k) * 6.0, y), 3.5 * (1.0 - avance),
			Color(COLOR_ORO, 0.6 * (1.0 - avance)))

	match accion:
		&"escudo", &"cambio", &"presentacion":
			_pintar_escudo(enemigo, accion, float(e["destello"]) / DURACION_DESTELLO, fase)
		&"cargando":
			var t: float = e["t"]
			var dir: Vector2 = e.get("dir", Vector2.DOWN)
			var largo: float = e.get("largo", 600.0)
			var avance := clampf(t / carga_fuego, 0.0, 1.0)
			var fija := t >= carga_fuego - fija_fuego
			# La linea, cada vez mas gruesa; fija, parpadea: ahora no te sigue.
			var alfa := 0.25 + 0.45 * avance
			if fija:
				alfa = 0.4 + 0.5 * absf(sin(t * 30.0))
			enemigo.draw_line(Vector2.ZERO, dir * largo, Color(COLOR_FUEGO, alfa), 2.0 + 6.0 * avance)
			enemigo.draw_circle(Vector2.ZERO, 14.0 + 26.0 * avance, Color(COLOR_FUEGO, 0.25 + 0.3 * avance))
		&"fuego":
			var queda := 1.0 - clampf(float(e["t"]) / DURACION_FUEGO, 0.0, 1.0)
			var dir: Vector2 = e["dir"]
			var hasta: Vector2 = dir * float(e["largo"])
			enemigo.draw_line(Vector2.ZERO, hasta, Color(COLOR_FUEGO, 0.5 * queda), ancho_fuego * (1.4 - 0.4 * queda))
			enemigo.draw_line(Vector2.ZERO, hasta, Color(1.0, 0.85, 0.4, 0.85 * queda), ancho_fuego * 0.55)
			enemigo.draw_line(Vector2.ZERO, hasta, Color(1.0, 1.0, 0.9, queda), ancho_fuego * 0.2)


## La burbuja: la del escudo (azul hielo, la del mago blanco) y la de cuando
## no se le puede dar (presentacion, cambio de fase), de oro.
func _pintar_escudo(enemigo: Enemigo, accion: StringName, destello: float, fase: float) -> void:
	var radio := enemigo.tipo.alto * 0.62
	var color := COLOR_HIELO if accion == &"escudo" else COLOR_ORO
	var alfa := 0.8
	if accion == &"escudo":
		var t: float = enemigo.estado["t"]
		# Parpadea cuando se le va a acabar.
		if duracion_escudo - t < 0.8:
			alfa = 0.35 + 0.65 * absf(cos(t * TAU * 3.0))
	enemigo.draw_circle(Vector2.ZERO, radio, Color(color, (0.1 + 0.15 * destello) * alfa))
	enemigo.draw_arc(Vector2.ZERO, radio, 0.0, TAU, 48, Color(color, (0.3 + 0.4 * destello) * alfa), 6.0 + 5.0 * destello, true)
	enemigo.draw_arc(Vector2.ZERO, radio, 0.0, TAU, 48, Color(color, 0.85 * alfa), 2.0, true)
	var giro := fase * 1.6
	enemigo.draw_arc(Vector2.ZERO, radio - 3.0, giro, giro + 0.9, 12, Color(1.0, 1.0, 1.0, 0.5 * alfa), 2.0, true)
	# Lo que le queda de escudo, como en la burbuja del mago blanco.
	if accion == &"escudo":
		var queda := clampf(1.0 - float(enemigo.estado["t"]) / duracion_escudo, 0.0, 1.0)
		enemigo.draw_arc(Vector2.ZERO, radio + 9.0, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.35 * alfa), 5.0, true)
		enemigo.draw_arc(Vector2.ZERO, radio + 9.0, -PI * 0.5, -PI * 0.5 + TAU * queda, 48,
			Color(1.0, 1.0, 1.0, 0.9 * alfa), 3.5, true)
