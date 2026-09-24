## Un mago de los que se pueden elegir al empezar: su arte y su ventaja.
##
## POR QUE UN RECURSO Y NO UN if EN EL JUGADOR:
## es la misma regla que los pisos, los enemigos y los objetos. Un mago nuevo es
## un .tres mas en resources/personajes/ y aparece solo en el menu; nadie tiene
## que tocar el jugador, el gestor ni la pantalla de seleccion.
##
## POR QUE LAS VENTAJAS SE SUMAN A LOS VALORES BASE Y NO SE APLICAN COMO UN
## OBJETO RECOGIDO: los objetos que se cogen por los pisos se pierden al empezar
## otra partida, y la ventaja del mago no: es lo que ES ese mago. Por eso
## Jugador.usar_personaje() la mete en los valores de fabrica.
class_name PersonajeJugable
extends Resource

@export var nombre: String = "Mago"
## Una linea, la que se lee al elegir. Conviene que diga numeros, no adjetivos.
@export_multiline var ventaja: String = ""
## Lo que pega ese mago de menos, si es que pega algo de menos. Se ensena aparte
## para que la eleccion sea honesta y no haya un mago que sea mejor a secas.
@export_multiline var pega: String = ""

@export_group("Arte")
@export var animaciones: SpriteFrames
## Solo para el menu: un TextureRect necesita una textura suelta, no animacion.
@export var retrato: Texture2D
## Color del nombre en la pantalla de seleccion.
@export var color: Color = Color.WHITE

@export_group("Ventajas")
## Corazones de mas (o de menos) con los que empieza.
@export var vida_maxima_extra: int = 0
## Velocidad punta de mas, en px/s.
@export var velocidad_extra: float = 0.0
## Multiplica la cadencia de disparo. Por debajo de 1 dispara mas rapido.
@export var cadencia_multiplicador: float = 1.0
@export var velocidad_bola_extra: float = 0.0
@export var radio_bola_extra: float = 0.0

@export_group("Ventajas del ataque cargado")
## Multiplica el tiempo de carga. Por debajo de 1, carga antes.
@export var tiempo_carga_multiplicador: float = 1.0
## Dano de mas del disparo cargado.
@export var dano_cargado_extra: int = 0
