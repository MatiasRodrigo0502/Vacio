# resources/proyectiles/

Lo que disparan los enemigos a distancia. Un `.tres` por proyectil, de tipo
`TipoProyectil` (`scripts/tipo_proyectil.gd`). Todos los mueve y dibuja el
mismo script, `scripts/proyectil_enemigo.gd`: lo que cambia son estos números.

| Proyectil | Estilo | Daño | Velocidad | Efecto | Lo tiran |
|---|---|---|---|---|---|
| `veneno.tres` | bola | 1 | 300 | frena al jugador 2,5 s (va al 60 %) | serpiente, planta venenosa |
| `magma.tres` | parábola | 2 | 330 | al caer deja un charco de lava 3,5 s | gólem de roca |
| `rayo.tres` | rayo | 2 | 1300 | ninguno: es rápido y va recto | cristal vivo |

Los tres estilos:

- **Bola**: va en línea recta. La paran las rocas y los muros.
- **Rayo**: igual, pero muy rápido. Por eso quien lo tira marca antes la
  línea de mira: sin ella no se podría esquivar.
- **Parábola**: va por el aire hasta donde estabas al lanzarla, así que pasa
  por encima de las rocas. Mientras vuela, un aro marca dónde va a caer.

Para un proyectil nuevo: otro `.tres` aquí y apuntarlo desde el `proyectil`
del enemigo que lo tire. Sin tocar código.
