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

## Los valores de 'ataque_especial', en el orden de su lista.
const ESPECIAL_BOLA := 0
const ESPECIAL_ESCUDO := 1

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

@export_group("Colores del disparo")
## Centro y resplandor de las bolas del disparo normal.
##
## El resplandor se pide aparte y no se deduce del centro con una formula: se
## probo, y la formula cambiaba el halo del mago oscuro (0,10 en un canal), que
## estaba ajustado a mano. Dos colores por ataque es poco trabajo y deja cada
## mago exactamente como se quiere.
@export var color_disparo: Color = Color(0.62, 0.84, 1.0)
@export var halo_disparo: Color = Color(0.35, 0.60, 1.0)
## Lo mismo para el ataque cargado: la bola que se forma al cargar y la que
## sale. Conviene que se distinga del normal, para saber que ha salido. Un
## mago cuyo ataque especial es el escudo no los usa.
@export var color_cargado: Color = Color(0.72, 0.52, 1.0)
@export var halo_cargado: Color = Color(0.52, 0.28, 0.95)

@export_group("Ventajas")
## Corazones de mas (o de menos) con los que empieza.
@export var vida_maxima_extra: int = 0
## Velocidad punta de mas, en px/s.
@export var velocidad_extra: float = 0.0
## Multiplica la cadencia de disparo. Por debajo de 1 dispara mas rapido. Hoy
## los tres magos van a 1: Matias quiso medio segundo entre bola y bola para
## todos (2026-10-09).
@export var cadencia_multiplicador: float = 1.0
@export var velocidad_bola_extra: float = 0.0
@export var radio_bola_extra: float = 0.0

@export_group("Ventajas del ataque cargado")
## Multiplica el tiempo de carga. Por debajo de 1, carga antes.
@export var tiempo_carga_multiplicador: float = 1.0
## Dano de mas del disparo cargado.
@export var dano_cargado_extra: int = 0

@export_group("Disparo normal")
## Cuanta vida quita cada bola normal a un enemigo. 1 es lo de siempre; con
## 0,5 hacen falta el doble de impactos. El ataque cargado no cambia.
@export var dano_disparo: float = 1.0
## Segundos que deja frenado a un enemigo cada bola normal (anda y dispara a
## la mitad). 0 = no frena.
@export var frena_disparo: float = 0.0

@export_group("Ataque especial")
## Lo que sale con el clic derecho o el espacio.
##
## Bola cargada: se mantiene y se suelta cuando el aro se cierra (los campos
## "del ataque cargado" de arriba). Escudo: se pulsa y sale un escudo
## direccional (EscudoDireccional), un arco pequeno delante del mago que para
## los disparos enemigos que le vienen de frente, durante 'duracion_escudo'.
## Despues hay que esperar 'recarga_escudo' para volver a sacarlo.
##
## POR QUE UNO U OTRO Y NO LOS DOS: es el mismo boton. Con los dos, pulsarlo
## haria dos cosas y no se sabria cual ha servido.
@export_enum("Bola cargada", "Escudo") var ataque_especial: int = ESPECIAL_BOLA
## Segundos que dura el escudo levantado.
@export var duracion_escudo: float = 3.0
## Segundos que tarda en poder volver a sacarse, contados desde que se baja.
@export var recarga_escudo: float = 5.0
