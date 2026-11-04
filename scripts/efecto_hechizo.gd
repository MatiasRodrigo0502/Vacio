## Una animacion de un hechizo que se pinta una vez y se va: el impacto de una
## bola, la explosion del meteoro. Solo se ve: el dano lo decide quien lo
## suelta, como con Explosion.
##
## De pie con la vista girada (Vista): son cosas vistas de lado, con su suelo
## abajo, aunque la bola que las suelta venga girada.
class_name EfectoHechizo
extends AnimatedSprite2D


## Suelta 'nombre' de 'arte' en 'sitio' (global), colgado de 'padre', con el
## orden de pintado 'capa' (por encima de los enemigos, por defecto).
static func soltar(padre: Node, arte: ArteHechizo, nombre: StringName, sitio: Vector2,
		capa: int = 7) -> void:
	if padre == null or arte == null or not arte.tiene(nombre):
		return
	var efecto := EfectoHechizo.new()
	padre.add_child(efecto)
	efecto.global_position = sitio
	efecto.z_index = capa
	efecto.rotation = Vista.giro
	efecto.add_to_group("de_pie")
	efecto.animation_finished.connect(efecto.queue_free)
	arte.poner(efecto, nombre)


## La marca que deja en el suelo: se queda un rato y se apaga. Por debajo de lo
## que se mueve por encima (enemigos y objetos).
static func dejar_marca(padre: Node, textura: Texture2D, sitio: Vector2,
		queda: float = 4.0, apagarse: float = 2.0) -> void:
	if padre == null or textura == null:
		return
	var marca := Sprite2D.new()
	marca.texture = textura
	marca.z_index = 2
	marca.rotation = Vista.giro
	marca.add_to_group("de_pie")
	padre.add_child(marca)
	marca.global_position = sitio
	var tiempo := marca.create_tween()
	tiempo.tween_interval(queda)
	tiempo.tween_property(marca, "modulate:a", 0.0, apagarse)
	tiempo.tween_callback(marca.queue_free)
