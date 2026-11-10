// Esconde lo que queda detras de una linea del mundo: la de delante del mago que
// dispara (BolaMagica.recortar_desde). Una bola grande nace en el centro del mago y
// asomaba por detras de el; asi solo se ve a partir de su parte delantera.
shader_type canvas_item;

// Un punto de la linea y hacia donde se ve (la direccion del disparo), en el mundo.
uniform vec2 punto;
uniform vec2 delante;

varying vec2 en_mundo;

void vertex() {
	en_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (dot(en_mundo - punto, delante) < 0.0) {
		discard;
	}
}
