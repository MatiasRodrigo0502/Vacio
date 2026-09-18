## Datos de un tipo de enemigo.
##
## POR QUE UN RESOURCE Y NO UNA ESCENA POR ENEMIGO:
## todos los enemigos se comportan igual (perseguir y hacer dano al tocar); lo
## unico que cambia son los numeros y el dibujo. Con una escena por enemigo
## habria que mantener cuatro archivos casi identicos. Asi, anadir un enemigo
## nuevo es crear un .tres y dejarlo en resources/enemigos/: la mecanica lee la
## carpeta entera y no hay que tocar ni una linea de codigo.
class_name TipoEnemigo
extends Resource

## Nombre legible, para depuracion.
@export var nombre: String = "Enemigo"

## Las animaciones. Ahora mismo todas tienen una sola: "moverse".
@export var animaciones: SpriteFrames = null

## Cuantos disparos aguanta.
@export var vida: int = 2

## Velocidad de persecucion en px/s. A 0 se queda quieto, como una planta.
@export var velocidad: float = 78.0

## Vida que quita al tocar al jugador.
@export var dano: int = 1

## Alto que ocupa en el mundo. El sprite se escala a esto.
@export var alto: float = 54.0

## A partir de que distancia deja de perseguir. Un radio corto convierte al
## enemigo en una emboscada: no se entera hasta que lo tienes encima.
@export var radio_vision: float = 620.0

## Primer piso en el que puede aparecer. Sirve para que los enemigos duros no
## salgan en los pisos de arriba.
@export_range(1, 12) var piso_minimo: int = 1
