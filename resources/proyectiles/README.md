# resources/proyectiles/

Lo que disparan los enemigos a distancia. Un `.tres` por proyectil, de tipo
`TipoProyectil` (`scripts/tipo_proyectil.gd`). Todos los mueve y dibuja el
mismo script, `scripts/proyectil_enemigo.gd`: lo que cambia son estos números.

| Proyectil | Estilo | Daño | Velocidad | Efecto | Lo tiran |
|---|---|---|---|---|---|
| `esquirla_corteza.tres`, `esquirla_manto.tres`, `esquirla_nucleo.tres` | bola | 20 / 30 / 40 | 300 / 340 / 380 | ninguno; lleva su dibujo (`arte`) | vigía de cada capa |
| `bola_nucleo.tres` | bola | 20 | 440 | ninguno; lleva su dibujo (`arte`) | Corazón del Núcleo |
| `esquirla_hielo.tres` | bola | 12 | 220 | frena | Corazón del Núcleo, con el escudo puesto |
| `veneno.tres` | bola | 20 | 300 | 3 s envenenado: va al 60 % y pierde 2 de vida poco a poco (`veneno_vida`); el veneno no mata | (de antes: serpiente, planta venenosa) |
| `magma.tres` | parábola | 45 | 330 | al caer deja un charco de lava 3,5 s | (de antes: gólem de roca) |
| `rayo.tres` | rayo | 50 | 1300 | ninguno: es rápido y va recto | (de antes: cristal vivo) |

Con `arte` (un `ArteHechizo`, como los hechizos de los magos), el proyectil se pinta
con su animación `vuelo`, girada hacia donde va, y al acabarse suelta `impacto`. Sin
él, se pinta por código con sus colores.

Los tres estilos:

- **Bola**: va en línea recta **hasta que da con algo**: una roca, un muro,
  el jugador o, si ha rebotado en el escudo del mago blanco, un enemigo. No
  tienen distancia máxima desde el 2026-11-03 (Matías): el veneno se
  apagaba a 800 px, en mitad de una sala, y lo rebotado se apagaba antes de
  llegar a ningún enemigo, porque contaba también lo que había recorrido
  hasta el escudo.
- **Rayo**: igual, pero muy rápido. Por eso quien lo tira marca antes la
  línea de mira: sin ella no se podría esquivar.
- **Parábola**: va por el aire hasta donde estabas al lanzarla, así que pasa
  por encima de las rocas. Mientras vuela, un aro marca dónde va a caer. Si
  bota en el escudo del mago blanco, su charco quema también a los enemigos
  (10 cada 0,5 s; no a los que vuelan).

Para un proyectil nuevo: otro `.tres` aquí y apuntarlo desde el `proyectil`
del enemigo que lo tire. Sin tocar código.
