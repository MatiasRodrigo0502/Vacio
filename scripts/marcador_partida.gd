## Lo que se sube a la clasificacion de una partida (Matias, 2026-11-19): el tiempo
## jugado, la precision del disparo basico y el metodo de control mas alto que se ha
## usado. Lo crea Principal y lo vuelve a empezar al reiniciar.
##
## Va aparte de RegistroPartida: ese apunta todo para equilibrar (en un archivo de
## este ordenador) y esto es solo lo que se ensena a los demas.
##
## - Tiempo: el de la partida sin pausas (el nodo se para con el arbol, igual que
##   en las ventanas del tutorial).
## - Precision: bolas del disparo basico que dan a un enemigo entre las que se han
##   disparado. Cada bola cuenta una vez aunque atraviese a varios; las de un arma
##   que dispara varias, cada una. El especial no cuenta.
## - Control: de menos a mas, botones, joysticks, raton y disparo automatico; se
##   queda el mas alto que se haya usado (Jugador.control_usado).
class_name MarcadorPartida
extends Node

enum MetodoControl { BOTONES, JOYSTICKS, RATON, AUTOMATICO }
## Como va en el JSON (y lo que acepta el servidor).
const NOMBRES_CONTROL := ["botones", "joysticks", "raton", "automatico"]
const TEXTOS_CONTROL := ["Botones", "Joysticks", "Ratón", "Disparo automático"]

var tiempo: float = 0.0
var disparos: int = 0
var impactos: int = 0
var control: MetodoControl = MetodoControl.BOTONES
var _parado: bool = false


func _init() -> void:
	name = "MarcadorPartida"
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not _parado:
		tiempo += delta


func empezar() -> void:
	tiempo = 0.0
	disparos = 0
	impactos = 0
	control = MetodoControl.BOTONES
	_parado = false


## Al ganar o perder: lo que pase despues (la pantalla final) no cuenta.
func parar() -> void:
	_parado = true


## Una bola del disparo basico: cuenta como disparada y, la primera vez que da a
## algo que se pueda herir, como impacto.
func contar_disparo(bola: BolaMagica) -> void:
	if _parado:
		return
	disparos += 1
	bola.impacto.connect(_al_impactar.bind(bola))


func _al_impactar(objetivo: Node2D, bola: BolaMagica) -> void:
	if _parado or bola.has_meta(&"marcador_contada") or not objetivo.has_method("herir"):
		return
	bola.set_meta(&"marcador_contada", true)
	impactos += 1


func usar_control(nivel: int) -> void:
	if not _parado and nivel > control:
		control = nivel as MetodoControl


func precision() -> float:
	return 0.0 if disparos == 0 else float(impactos) / disparos * 100.0


## PC (el ejecutable de escritorio), movil (la app de Android) o navegador (la web,
## tambien en el movil).
static func dispositivo() -> String:
	if OS.has_feature("web"):
		return "navegador"
	if OS.has_feature("android"):
		return "movil"
	return "pc"


## El nombre del mago en la clasificacion: su archivo («1_mago_oscuro»). La
## clasificacion saca de ahi su cara (PanelClasificacion).
static func id_mago(personaje: PersonajeJugable) -> String:
	return personaje.resource_path.get_file().get_basename().trim_suffix(".tres")


## Lo que se manda a la funcion del servidor (Cuenta.subir_puntuacion). La
## precision va redondeada a una decima, que es lo que se ensena.
func datos(personaje: PersonajeJugable, piso: int, victoria: bool) -> Dictionary:
	return {
		"mago": id_mago(personaje),
		"dispositivo": dispositivo(),
		"control": NOMBRES_CONTROL[control],
		"piso": piso,
		"victoria": victoria,
		"tiempo_s": snappedf(tiempo, 0.1),
		"precision": snappedf(precision(), 0.1),
		"disparos": disparos,
		"impactos": impactos,
		"version_juego": GestorProgreso.version_juego(),
	}
