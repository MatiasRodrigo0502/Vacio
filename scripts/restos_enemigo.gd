## Lo que queda de un enemigo al morir: su animacion de muerte (el destello, se
## rompe, cae) y los restos un momento en el suelo. Solo se ve.
##
## POR QUE UN NODO APARTE Y NO EL PROPIO ENEMIGO, como en el paquete: para el
## juego, el enemigo muere de golpe. En ese momento la sala lo cuenta, se abren
## las puertas y da su botin. Si se quedara 3 s mas haciendo su animacion, cada
## cosa que mira a los enemigos (las bolas, el disparo automatico, el agujero
## negro, la red) tendria que saber que ese ya no cuenta.
##
## De pie con la vista girada (Vista), como el enemigo del que sale.
class_name RestosEnemigo
extends AnimatedSprite2D

## Lo que se quedan en el suelo al acabar la animacion, y lo que tardan en irse.
const QUEDAN: float = 1.5
const APAGARSE: float = 0.8


static func soltar(padre: Node, animaciones: SpriteFrames, nombre: StringName, sitio: Vector2,
		escala: Vector2, desfase: Vector2) -> void:
	if padre == null or not animaciones.has_animation(nombre):
		return
	var restos := RestosEnemigo.new()
	restos.sprite_frames = animaciones
	restos.scale = escala
	restos.offset = desfase
	# Por debajo de los enemigos vivos (z 5): los restos no tapan a nadie.
	restos.z_index = 4
	restos.rotation = Vista.giro
	restos.add_to_group("de_pie")
	padre.add_child(restos)
	restos.global_position = sitio
	restos.animation_finished.connect(restos._apagarse)
	restos.play(nombre)


func _apagarse() -> void:
	var tiempo := create_tween()
	tiempo.tween_interval(QUEDAN)
	tiempo.tween_property(self, "modulate:a", 0.0, APAGARSE)
	tiempo.tween_callback(queue_free)
