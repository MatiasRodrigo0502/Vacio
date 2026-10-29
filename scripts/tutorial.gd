## El tutorial del piso 1: una ventana (AvisoTutorial) al entrar en cada sala.
##
## Pedido por Matias el 2026-10-29: «que te explique como funciona todo y en
## la tercera sala te explique que hay que matar a los enemigos», y luego
## «que en vez de texto se abriera un pop up». El piso 1 es una fila de salas
## (MapaSalas, en_fila) y cada una ensena una cosa:
##   1. a que se juega, moverse, disparar y la pausa;
##   2. el ataque especial (el del mago elegido), las rocas, la vida y el mapa;
##   3. la primera pelea: hay que matarlos a todos para que se abran las
##      puertas (los enemigos los pone Piso, de DatosPiso.enemigos_tutorial);
##   4. los objetos (el del piso esta en el centro) y los vendajes;
##   5. la bajada, y lo que espera mas abajo.
## Antes eran carteles pintados en el suelo de la sala de inicio.
##
## Cada ventana sale una vez por sesion del juego: al reiniciar o al volver
## a empezar desde el menu no se repiten (la del especial si, si se cambia de
## mago, porque cuenta otra cosa). Cerrar el juego las vuelve a sacar.
##
## Los textos estan aqui y no en una escena porque dependen de las teclas
## elegidas en Controles y del mago: [k]...[/k] resalta (AvisoTutorial), y
## {mover}, {disparar} y {especial} se rellenan al abrir la ventana.
class_name Tutorial
extends Node

## Lo que espera desde que se entra en una sala hasta que sale su ventana: lo
## que tarda la camara en llegar a ella. La ventana para el juego, y parado a
## medio camino se veria media sala de cada.
const ESPERA: float = 0.45

const PASOS: Array[Dictionary] = [
	{
		"titulo": "Bienvenido a Vacío",
		"color": Color(1.0, 0.85, 0.55),
		"texto": "Tienes que bajar los 12 pisos, hasta el núcleo de la Tierra.\n"
			+ "[k]{mover}[/k] para moverte.\n"
			+ "[k]{disparar}[/k] o [k]clic izquierdo[/k] para disparar.\n"
			+ "[k]Esc[/k]: pausa, reiniciar o volver al menú.\n"
			+ "Cuando quieras, cruza la puerta: cada sala te enseña algo nuevo.",
	},
	{
		"titulo": "Tu ataque especial",
		"color": Color(0.8, 0.66, 1.0),
		"texto": "{especial}\n"
			+ "Solo tienes [k]uno por piso[/k]: vuelve al bajar al siguiente.\n"
			+ "Las [k]rocas[/k] son sólidas: te tapan y no las puedes cruzar.\n"
			+ "Arriba a la izquierda, tu [k]vida[/k]; arriba a la derecha, el [k]mapa[/k] del piso.",
	},
	{
		"titulo": "¡Enemigos!",
		"color": Color(1.0, 0.45, 0.38),
		"texto": "[k]Mata a todos los enemigos[/k]: las puertas no se abren hasta que no quede ninguno.\n"
			+ "Los [k]slimes[/k] explotan al morir y se parten en dos: dispárales de lejos.\n"
			+ "Cada número es la vida que quitas; en rojo, la que te quitan.",
	},
	{
		"titulo": "Objetos",
		"color": Color(0.6, 1.0, 0.66),
		"texto": "Los [k]objetos[/k] te mejoran para toda la partida: pasa por encima para cogerlo.\n"
			+ "Hay uno en cada piso, y a veces lo suelta un enemigo.\n"
			+ "Desde el piso 2, al limpiar una sala puede caer un [k]vendaje[/k]: cura 60.",
	},
	{
		"titulo": "La bajada",
		"color": Color(1.0, 0.85, 0.55),
		"texto": "Entra en el [k]círculo[/k] para bajar al piso 2.\n"
			+ "Más abajo: más salas, más enemigos, pinchos, lava y agujeros.\n"
			+ "Cada piso esconde una [k]sala secreta[/k] con un cofre: si ves una pared agrietada, dispárale.\n"
			+ "Y en el piso 12 te espera el [k]Mago Caído[/k]. Suerte.",
	},
]

## Las ventanas que ya han salido en esta sesion del juego. Estatico: el piso
## (y este nodo con el) se rehace al reiniciar, y la lista tiene que seguir.
static var _vistas: Dictionary = {}

var _salas: Array[Sala] = []
var _aviso: AvisoTutorial


## Lo arranca Piso al construirse, con las salas ya hechas. La primera
## ventana sale nada mas empezar; las demas, al entrar en su sala.
func empezar(piso: Piso) -> void:
	_salas = piso.salas()
	_aviso = AvisoTutorial.new()
	add_child(_aviso)
	piso.sala_cambiada.connect(_al_entrar)
	_al_entrar(_salas[0])


func _al_entrar(sala: Sala) -> void:
	var indice := _salas.find(sala)
	if indice < 0 or indice >= PASOS.size() or _vistas.has(_clave(indice)):
		return
	# Un temporizador que se para con el juego (el false): si se pausa justo
	# al entrar, la ventana espera a que se quite la pausa. Conectado a este
	# nodo y no con await: si el piso se va antes (en cooperativo se puede
	# bajar sin haberla cerrado), la conexion se va con el.
	get_tree().create_timer(ESPERA, false).timeout.connect(_mostrar.bind(indice))


func _mostrar(indice: int) -> void:
	var clave := _clave(indice)
	if _vistas.has(clave):
		return
	_vistas[clave] = true
	var paso: Dictionary = PASOS[indice]
	_aviso.mostrar(paso["titulo"], _rellenar(paso["texto"]), paso["color"])


## La del especial va por mago: con otro mago cuenta otra cosa.
func _clave(indice: int) -> String:
	if indice == 1 and GestorProgreso.personaje_elegido != null:
		return "%d:%s" % [indice, GestorProgreso.personaje_elegido.nombre]
	return str(indice)


func _rellenar(texto: String) -> String:
	var mover := "Flechas" if Controles.flechas_para_mover else "W A S D"
	var disparar := "W A S D" if Controles.flechas_para_mover else "Flechas"
	return texto.format({
		"mover": mover,
		"disparar": disparar,
		"especial": _linea_especial(),
	})


## Lo que hace el especial del mago con el que se juega, y como se saca.
func _linea_especial() -> String:
	var mago := GestorProgreso.personaje_elegido
	if mago != null and mago.ataque_especial == PersonajeJugable.ESPECIAL_ESCUDO:
		return "Pulsa [k]clic derecho[/k] o [k]espacio[/k]: sale tu [k]escudo burbuja[/k], que te cubre unos segundos."
	var nombre := mago.nombre_especial() if mago != null else "bola cargada"
	return "Mantén [k]clic derecho[/k] o [k]espacio[/k] y suéltalo: sale tu [k]%s[/k]." % nombre
