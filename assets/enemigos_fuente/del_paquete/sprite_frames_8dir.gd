class_name SpriteFrames8Dir
extends RefCounted
## Crea un SpriteFrames a partir de sprite sheets de 8 FILAS (direcciones) x N COLUMNAS (frames).
## Cada animación se registra 8 veces: "caminar_0" ... "caminar_7" (fila = dirección).
##
## Uso:
##   sprite.sprite_frames = SpriteFrames8Dir.construir([
##       {"nombre": "caminar", "textura": load("res://enemigos/golem/golem_corteza_caminar.png"),
##        "columnas": 4, "fps": 8.0, "bucle": true},
##       ...
##   ])
## Y para elegir la fila según hacia dónde mira:  SpriteFrames8Dir.fila(direccion)


static func construir(animaciones: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in animaciones:
		var textura: Texture2D = a["textura"]
		var columnas: int = a["columnas"]
		var ancho := textura.get_width() / columnas
		var alto := textura.get_height() / 8
		for fila in 8:
			var nombre := "%s_%d" % [a["nombre"], fila]
			sf.add_animation(nombre)
			sf.set_animation_speed(nombre, a["fps"])
			sf.set_animation_loop(nombre, a["bucle"])
			for c in columnas:
				# AtlasTexture = un "recorte" de la hoja, sin duplicar la imagen en memoria
				var recorte := AtlasTexture.new()
				recorte.atlas = textura
				recorte.region = Rect2(c * ancho, fila * alto, ancho, alto)
				sf.add_frame(nombre, recorte)
	return sf


## 0=E, 1=SE, 2=S, 3=SO, 4=O, 5=NO, 6=N, 7=NE (mismo orden que los magos)
static func fila(direccion: Vector2) -> int:
	return wrapi(roundi(direccion.angle() / (PI / 4.0)), 0, 8)
