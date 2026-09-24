# assets/

Arte del juego. Aquí entra **solo lo que se usa**, ya recortado y reescalado;
los packs originales viven fuera del repositorio (ver `CREDITS.md` en la raíz).

## mago_rojo/

El segundo mago elegible. Mismo formato que `mago_oscuro/`: `atlas_8dir.png`
(8 direcciones × 6 poses de 64×72), su `SpriteFrames` y `retrato.png`.

Vino como una **brújula animada** en un GIF de 576×648 y 6 fotogramas: 3×3
celdas con el hueco del centro, cada celda a 3× de tamaño. El 3× resultó ser de
píxel entero (comprobado: los 41.472 bloques de 3×3 son de un solo color), así
que dividir por 3 recupera el original sin perder un píxel. El fondo se quita
con un relleno desde el borde **por color exacto**, sin tolerancia: el GIF no
tiene suavizado, y sin tolerancia no hay riesgo de comerse los píxeles oscuros
del mago.

Las direcciones se verificaron antes de fiarse del orden de la brújula, y la
primera medida engañó: el desvío de la barba daba las diagonales al revés,
porque el detector cazaba también la bolsa gris del cinturón. Lo que sí lo
resuelve es comparar cada diagonal con los perfiles ya confirmados: cada una se
parece un **94 %** a su lado y un **69 %** al contrario.

Como el oscuro, cada dirección se ha centrado sobre el eje de sus botas con
desplazamientos de píxeles enteros.

## mago_oscuro/

El primero de los dos magos elegibles, y el primero que mira a los **ocho**
lados. Dos archivos:

- `atlas_8dir.png` — 384×576: 8 filas (una por dirección) × 6 poses de 64×72.
- `animaciones_mago_oscuro.tres` — 48 `AtlasTexture` recortadas de ese atlas y
  16 animaciones: `caminar_` y `quieto_` por dirección. Es lo que carga
  `Jugador.tscn`.

Un atlas y no 48 PNG sueltos porque el pack ya venía así y porque es un archivo
en vez de 48 en el repositorio. Las regiones las define el `.tres`.

El pack vino limpio: fondo transparente, tamaños iguales y **los rótulos del
orden de filas dicen la verdad** (comprobado: los pares opuestos son espejo
exacto al 100 %, y la cara se desplaza ±7,5 px justo a los lados que dice).

Lo único que hubo que arreglar es que **el eje de los pies no estaba en el mismo
sitio en cada dirección**: 23,7 px mirando a la derecha y 39,3 mirando a la
izquierda, o sea que el mago se corría 15 px de lado al girarse. Cada dirección
se ha centrado sobre sus botas, con desplazamientos de un número entero de
píxeles: esto es pixel art de verdad y cualquier reescalado o decimal
emborronaría los bordes duros. Después del centrado el eje va de 31,2 a 32,0 en
las ocho, y el espejo entre opuestas sigue siendo exacto.

**Tamaño en pantalla**: se dibuja a escala 1, sin escalar, porque es pixel art.
El dibujo ocupa hasta la fila 68 de un fotograma de 72, así que el `offset` de
la escena es −33 (y no −36) para que el borde de abajo del dibujo caiga en el
origen del nodo, que es donde están los pies.

**Contraste medido contra el suelo: 1,66:1**, mejor que el mago morado anterior
(1,40) aunque por debajo del nigromante (1,81).

`retrato.png` es la pose de reposo de frente recortada, solo para el menú: un
`TextureRect` necesita una textura suelta, no una animación.

## mago/

**Fuera de uso.** El personaje anterior, el primero que miró a los cuatro
lados. 15 PNG de 108×134 (`abajo_0..3`, `izquierda_0..3`, `derecha_0..3`,
`arriba_0..2`) y `animaciones_mago.tres`, con ocho animaciones: `caminar_` y
`quieto_` por cada dirección.

Salieron de una hoja de 4×4 casillas rotuladas. Esa hoja traía dos defectos,
los dos encontrados midiendo y no mirando:

- **Las dos filas de lado son la misma pose y miran al mismo sitio**: siluetas
  93 % iguales tal cual y solo 62 % en espejo. Y miran a la **derecha**, no a la
  izquierda que dice el rótulo: el centro de la piel de la cara cae 10 px a la
  derecha del centro de la cabeza, mientras que en la fila frontal (que sabemos
  que es de frente) ese desvío es de 4. Así que la fila de lado se usa tal cual
  para la derecha y **reflejada** para la izquierda.
- **El fotograma ARRIBA 3 tiene dos báculos**, uno en cada mano. Se descarta,
  así que andar hacia arriba usa tres poses en vez de cuatro. Para que el paso
  no vaya más rápido, esa animación va a 7,5 fps en vez de 10: el ciclo dura
  los mismos 0,4 s.

Cada fila de la hoja tenía al mago a una altura distinta dentro de su casilla,
así que la línea de suelo se mide **por dirección**; si se midiera para toda la
hoja, el mago pegaría un salto vertical al girarse. La referencia son las filas
con píxeles sólidos (alfa alto y anchura de bota), no la caja del alfa: debajo
de los pies hay restos de sombra suave, distintos en cada fila. Con ese filtro
las cuatro direcciones miden lo mismo de alto (221 px en la hoja), que es la
señal de que la referencia es buena.

El lienzo se centra en los pies y es simétrico, porque la derecha es la
izquierda reflejada y el eje tiene que caer en el mismo sitio.

**Contraste medido contra el suelo: 1,43:1.** Es el personaje más oscuro que ha
tenido el juego (el nigromante daba 1,81:1 y el mago azul original 1,55:1). Se
lee gracias al orbe morado y al ribete claro de la túnica.

## nigromante/

**Fuera de uso** (no tenía más que vista de frente). 6 PNG de 134×150 más su
`SpriteFrames`. Se deja para poder volver atrás cambiando una línea en
`Jugador.tscn`.

## personaje/

El mago anterior (BlueWizard), **ya no se usa**: se deja para poder volver
atrás cambiando una línea en `Jugador.tscn`. 40 PNG de 73×128:

- `quieto_00..19.png` — animación de reposo
- `caminar_00..19.png` — animación de andar
- `animaciones_mago.tres` — el `SpriteFrames` que las agrupa, con sus
  velocidades. Es lo que carga `Jugador.tscn`.

Los frames originales eran de 512×512 con el personaje ocupando solo 160×280
en el centro: un 83% del archivo era transparencia. Recortarlos a la caja común
de las tres animaciones (la misma para todas, o el personaje daría saltos al
cambiar de animación) bajó el conjunto de 4,1 MB a 441 KB.

**Tamaño en pantalla**: el sprite se dibuja a escala 0,5 desde `Jugador.tscn`,
o sea 64 px de alto, y el origen del nodo está a los pies. Si quieres el mago
más grande o más pequeño, cambia esa escala en la escena; la forma de colisión
es independiente y está aparte (círculo de radio 15 sobre la base de la túnica).

Nota sobre `.gitignore`: los `*.import` no se versionan, los regenera Godot al
abrir el proyecto.

## cueva/ y musgo/

Un pack de arte por carpeta, y **un piso apunta a su pack desde su `.tres`**.
Ahora mismo:

| Piso | Catálogo | Qué se ve |
|---|---|---|
| 1 | `musgo/catalogo_musgo.tres` | matorrales, rocas con musgo, lianas con pinchos y plantas |
| 2 | `cueva/catalogo_cueva_vegetal.tres` | rocas de cueva + su vegetación seca |
| 3–12 | `cueva/catalogo_cueva.tres` (por defecto) | solo rocas, sin vegetación |

El musgo va arriba y la cueva debajo, que es el orden que pide el tema: se
empieza en la superficie y se baja a la roca. Los pisos 3 al 12 se quedan con
roca pelada a propósito, hasta que haya arte
propio para ellos. Y sin vegetación: no crecen plantas en el manto.

### Las familias de un catálogo

- `piedra_*` — piezas pequeñas repartidas por el suelo; **también quitan vida**
- `roca_*` — obstáculos principales, familia por defecto
- `bloque_*` — obstáculos angulares, para los pisos del núcleo
- `grupo_*` — obstáculos grandes; en el pack de musgo son las lianas con pinchos
- `vegetacion_*` — plantas; crecen sobre las plataformas y son lo único
  decorativo que queda: no chocan, porque una planta no es una roca
- `plataforma_*` — repisas y losas anchas que se reparten por el suelo

**Por qué un catálogo `.tres` y no leer la carpeta**: el orden de los archivos
en disco no es estable entre sistemas, y los 12 pisos tienen que ser idénticos
en las tres máquinas del equipo. Con la lista fija dentro del `.tres`, la roca
número 3 es la misma para todo el mundo.

### Añadir un pack nuevo (pisos 3 al 12)

1. Recorta las piezas y guárdalas en `assets/<pack>/` con los prefijos de
   arriba.
2. Crea `catalogo_<pack>.tres` con las cinco listas.
3. En el `.tres` del piso, apunta `catalogo_arte` a ese catálogo.

No hace falta tocar ni una línea de GDScript.

### Plataformas

Cada piso reparte entre 3 y 6 plataformas bajas, y la vegetación crece **encima
de ellas** en vez de suelta por el suelo. Sueltas parecían puestas al azar,
porque lo estaban; agrupadas sobre una repisa cuentan algo: ahí hay tierra y por
eso crece algo.

**Las plataformas hacen daño**, igual que las rocas: pasan por el pool de
obstáculos, no son decoración. La vegetación que crece encima sí es decoración
y no choca, para que el borde de la losa sea exactamente lo que quita vida.

Se pintan **a la misma luminosidad que las rocas**: lo que hace daño tiene que
verse igual, sea roca o losa. No basta con darles el mismo tinte, porque la
textura de las repisas es de por sí mucho más clara; llevan un factor 0,6
encima, calculado midiendo una captura (suelo 34, rocas 49, losas sin corregir
71). Está en `tinte_losa`, dentro de `_colocar_plataformas()`.

Los pisos 3 al 12 tienen plataformas de piedra pero sin plantas: sus catálogos
no llevan vegetación.

### El borde del área

Cada piso se rodea de rocas del pack que tenga asignado, para que el límite no
sea una línea dibujada sino la pared de la cueva. Son **decoración pura**: van
por fuera del borde y no chocan con nada, la colisión sigue siendo el muro
invisible. Se dejan huecos en el centro de arriba y de abajo, donde aparece el
jugador y donde está el círculo de salida.

Salen unos 100-135 sprites por piso, sin física. Para hacerlo más o menos denso
está `_colocar_borde()` en `scripts/piso.gd`.

### Tinte

Las rocas y plantas se tintan en tiempo de ejecución según la profundidad. Ese
tinte no es decorativo: decide si el obstáculo se distingue del suelo. Está
explicado y medido en `tinte_profundidad()`, en `scripts/piso.gd`.

## manto/

Pack propio para los pisos del **manto**, el siguiente paso bajando desde la
cueva. Mismas familias y prefijos que `cueva/`, así que no hay que tocar
GDScript: basta con apuntar `catalogo_arte` del piso a su catálogo.

| Familia | Piezas | Qué es |
|---|---|---|
| `piedra_*` | 8 | basalto pequeño, algunas con grieta de magma |
| `roca_*` | 10 | montículos de basalto con grietas incandescentes |
| `bloque_*` | 7 | **columnas de basalto** hexagonales, de 1 a 3 juntas |
| `grupo_*` | 6 | montones de 3-5 rocas solapadas |
| `plataforma_*` | 5 | costra de lava enfriada: placas con juntas de magma |
| `vegetacion_*` | 6 | **cristales de olivino** (verdes) y espinela (naranja) |

Dos catálogos:

- `catalogo_manto.tres`: con los cristales en la lista `vegetacion`. Crecen
  sobre las plataformas y no chocan, igual que las plantas: en el manto no hay
  plantas, pero sí minerales.
- `catalogo_manto_sin_cristales.tres`: roca pelada, con `vegetacion` vacía.

**Luminosidad medida**: las rocas del manto tienen una media de 31 en lo
opaco, frente a 33 de las de cueva. Es a propósito: el tinte por
profundidad de `tinte_profundidad()` está calibrado para ese brillo, y lo
que hace daño tiene que verse igual en todos los pisos. Las grietas de magma
son finas para no subir esa media: se leen por el color, no por la cantidad
de luz.

Como la vegetación de `cueva/`, los cristales conservan su lienzo de
192×192 con aire alrededor; el resto de piezas va recortado a su contenido.

Todo sale de un generador procedural con semillas fijas: volver a ejecutarlo
da exactamente los mismos PNG en las tres máquinas.

## enemigos/ (nuevos)

Siete enemigos más, en el mismo formato que los slimes y las plantas:
10 fotogramas `<nombre>_00..09.png` y un `animaciones_<nombre>.tres` con la
animación `moverse` a 12 fps en bucle.

| Enemigo | Tamaño | Movimiento | Encaja en |
|---|---|---|---|
| `slime_magma` | 128×85 | respira como `slime_verde`, la costra se agrieta al estirarse | manto |
| `murcielago` | 128×96 | aleteo con subida y bajada | cueva |
| `golem_roca` | 128×96 | dos saltitos por ciclo, se aplasta al aterrizar | cueva / manto |
| `cristal_vivo` | 128×96 | estático, late y brilla (trampa fija, como las plantas) | manto |
| `rata` | 128×96 | anda con paso alternado y cola ondulante | musgo / cueva |
| `serpiente` | 128×96 | reptar con una onda que viaja hacia la cola, saca la lengua | musgo |
| `fantasma` | 128×96 | flota, semitransparente, el faldón ondea | cualquiera (pisos oscuros) |

`slime_magma` usa la misma caja de 128×85 que `slime_verde`, así que puede
sustituirlo sin tocar su forma de colisión.

**La rata y la serpiente miran a la derecha.** Cuando se muevan hacia la
izquierda, `flip_h = true` en el `AnimatedSprite2D`. El resto son simétricos
o se ven de frente.

Todos los ciclos son funciones periódicas de la fase del fotograma, así que
el 09 enlaza con el 00 sin tirón.
