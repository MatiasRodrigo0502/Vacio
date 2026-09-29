// Lava viva: el calor late y la superficie fundida ondula.
//
// La textura trae el charco pintado, y "calor" dice que partes estan fundidas
// (blanco) y cuales son roca o costra (negro). Solo lo caliente se mueve y
// brilla: el borde de basalto y las placas se quedan quietos, como pasaria de
// verdad, y eso es lo que hace que se lea como liquido.
shader_type canvas_item;

uniform sampler2D calor : filter_linear;
// Cada charco late a su ritmo: si todos fueran a la vez, se notaria el truco.
uniform float semilla = 0.0;
// 0 = viva, 1 = apagada. Lo sube el charco que deja el magma al enfriarse.
uniform float enfriado : hint_range(0.0, 1.0) = 0.0;

// El color del vertice (el modulate del nodo y el del draw_texture_rect),
// sin la textura. OJO: en fragment() COLOR ya llega multiplicado por la
// textura; si se vuelve a multiplicar por ella, sale la textura al cuadrado:
// el borde de basalto se ennegrecia y el resplandor semitransparente
// desaparecia. Por eso el tinte se coge aqui, antes de la textura.
varying vec4 tinte_vertice;

void vertex() {
	tinte_vertice = COLOR;
}

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x),
		mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float h = texture(calor, UV).r;
	float t = TIME + semilla * 7.0;

	// Ondulacion: solo donde esta fundido, y muy poca, o parece agua.
	vec2 ola = vec2(sin(t * 1.3 + UV.y * 18.0), cos(t * 1.1 + UV.x * 16.0)) * 0.004 * h;
	vec4 color = texture(TEXTURE, UV + ola);

	// Latido: manchas de ruido que se desplazan despacio y suben y bajan el
	// brillo de lo caliente.
	float mancha = ruido(UV * 5.0 + vec2(t * 0.12, -t * 0.09));
	float latido = sin(t * 1.7 + mancha * 6.283) * 0.5 + 0.5;
	color.rgb += vec3(1.0, 0.55, 0.18) * h * (latido * 0.42 - 0.12);

	// Al enfriarse, lo caliente se apaga hacia rojo oscuro.
	color.rgb = mix(color.rgb, color.rgb * vec3(0.32, 0.16, 0.12), enfriado * h);

	COLOR = color * tinte_vertice;
}
