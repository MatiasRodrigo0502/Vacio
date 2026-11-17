// Esconde lo que queda detras de una curva del mundo: la de delante del mago que
// dispara (BolaMagica.recortar_desde). Una bola grande nace en el centro del mago y
// asomaba por detras de el; asi solo se ve a partir de su parte delantera.
//
// LA CURVA, COMO UNA «C» DELANTE DEL MAGO («·C», Matias, 2026-11-17): antes era una
// recta, y se veia demasiado el corte. Ahora es una parabola con la punta en
// 'punto', lo mas cerca del mago, y los brazos hacia delante: a los lados se
// esconde un poco mas. Y el borde no es seco: se desvanece en BORDE px.
shader_type canvas_item;

// La punta de la curva y hacia donde se ve (la direccion del disparo), en el mundo.
uniform vec2 punto;
uniform vec2 delante;
// Lo que se adelanta la curva a 'radio_curva' px del centro: la mitad de eso. Con
// 40, a 20 px de lado se adelanta 5, y a 40, 20. La parabola de una circunferencia
// de ese radio.
uniform float radio_curva = 40.0;
// Lo que tarda en desvanecerse el borde, en px.
uniform float borde = 6.0;

varying vec2 en_mundo;

void vertex() {
	en_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 d = en_mundo - punto;
	float avance = dot(d, delante);
	float lado = dot(d, vec2(-delante.y, delante.x));
	// Por delante de la curva, positivo; por detras, negativo.
	float pasado = avance - lado * lado / (2.0 * radio_curva);
	if (pasado < 0.0) {
		discard;
	}
	COLOR.a *= smoothstep(0.0, borde, pasado);
}
