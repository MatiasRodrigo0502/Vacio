# resources/enemigos/

Un `.tres` por tipo de enemigo. Cada uno es un `TipoEnemigo`
(`scripts/tipo_enemigo.gd`).

**Añadir un enemigo nuevo no toca código**: la mecánica `enemigos.tres` lee esta
carpeta entera y reparte por el piso los tipos que ya pueden salir a esa
profundidad. Basta con dejar aquí otro `.tres`.

## Los que hay

| Tipo | Vida | Velocidad | Visión | Desde el piso |
|---|---|---|---|---|
| Slime verde | 2 | 78 | 620 | 1 |
| Planta venenosa | 3 | 46 | 300 | 3 |
| Slime naranja | 3 | 104 | 760 | 5 |
| Planta azul | 2 | 132 | 420 | 7 |

La progresión está en `piso_minimo`: arriba solo hay slimes verdes y según
bajas se suman los duros. `radio_vision` cambia mucho el carácter — la planta
venenosa tiene 300, así que no se entera de que estás ahí hasta que la tienes
encima y funciona como emboscada; el slime naranja tiene 760 y te persigue
desde lejos.

## Por qué son Resources y no una escena por enemigo

Todos se comportan igual: perseguir y hacer daño al tocar. Lo único que cambia
son los números y el dibujo. Con una escena por enemigo habría cuatro archivos
casi idénticos que mantener.
