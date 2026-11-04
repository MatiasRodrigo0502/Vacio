## Lo que se ve de un hechizo de un mago: sus animaciones y dónde va cada una.
## Pedido por Matias el 2026-11-04, con el arte de los cuatro magos (lo prepara
## herramientas/generar_magos.py).
##
## POR QUE UN RECURSO: es la misma regla que los magos y los enemigos. Cada mago
## dice en su .tres que arte lleva (PersonajeJugable.arte_disparo y
## arte_especial), y la bola, el agujero o el escudo solo saben pintar "un
## arte". Sin arte siguen pintandose por codigo, como el rocio del mago verde.
##
## Las animaciones que cada cosa busca: la bola, "vuelo" e "impacto"; el
## especial de bola cargada, "vuelo", "carga" y "explosion"; el agujero negro,
## "abrir", "bucle" y "colapso"; el escudo, "aparece", "bucle" y "rompe", cada
## una _detras y _delante.
class_name ArteHechizo
extends Resource

@export var animaciones: SpriteFrames
## El desfase de cada animacion: lo que hay que mover el dibujo para que el
## punto que importa (la punta del proyectil, el centro de la explosion, el
## suelo) quede en el origen del nodo.
@export var desfases: Dictionary = {}
## El radio de bola para el que "vuelo" mide lo que mide. Una bola mas gorda
## (el orbe hinchado) se pinta mas grande en la misma proporcion.
@export var radio_base: float = 11.0

## Las hojas de los estados (envenenado, ralentizado): poses de 96 x 96 a 10 por
## segundo, con los pies a 86 px de arriba.
const LADO_ESTADO: float = 96.0
const PIES_ESTADO: float = 86.0
const POSES_POR_SEGUNDO: float = 10.0
## El radio para el que la hoja mide lo que mide. Con esto, en un enemigo (radio
## = 0,62 de su alto) el aro de los pies le cubre el cuerpo y lo de arriba sale
## un poco por encima de su cabeza. Medido con la hoja: el aro mide 40 px de
## ancho y lo de arriba llega a 76 sobre los pies.
const RADIO_ESTADO: float = 37.0


## Pinta una pose de una hoja de estado, desde el _draw de quien la lleva.
static func pintar_estado(lienzo: CanvasItem, hoja: Texture2D, pies: Vector2, radio: float,
		fase: float) -> void:
	var poses := int(hoja.get_width() / LADO_ESTADO)
	var pose := int(fase * POSES_POR_SEGUNDO) % poses
	var escala := radio / RADIO_ESTADO
	var tamano := Vector2(LADO_ESTADO, LADO_ESTADO) * escala
	var sitio := pies - Vector2(tamano.x * 0.5, PIES_ESTADO * escala)
	lienzo.draw_texture_rect_region(hoja, Rect2(sitio, tamano),
		Rect2(pose * LADO_ESTADO, 0.0, LADO_ESTADO, LADO_ESTADO))


func tiene(nombre: StringName) -> bool:
	return animaciones != null and animaciones.has_animation(nombre)


## Pone esa animacion en el sprite, en su sitio, desde el principio.
func poner(sprite: AnimatedSprite2D, nombre: StringName) -> void:
	sprite.sprite_frames = animaciones
	sprite.offset = desfases.get(String(nombre), Vector2.ZERO)
	sprite.play(nombre)
