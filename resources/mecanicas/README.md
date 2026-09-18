# resources/mecanicas/

Cada mecánica del juego es un `Resource` que hereda de `Mecanica`
(`scripts/mecanica.gd`) y vive aquí como un `.tres` independiente.

`GestorProgreso` lee esta carpeta entera al arrancar, ordena las mecánicas por
`piso_desbloqueo` y le pasa a cada piso solo las que están activas. **No hay
ningún `if` ni `match` con nombres de mecánicas en el gestor**: por eso añadir
una mecánica nueva no obliga a tocar su código.

## Añadir una mecánica (fases siguientes)

1. `scripts/mecanicas/mi_mecanica.gd`:

   ```gdscript
   class_name MiMecanica
   extends Mecanica

   func aplicar_a_piso(piso: Node) -> void:
       # lo que haga falta: añadir nodos, cambiar la salida, spawnear cosas...
       pass
   ```

2. Crea el `.tres` aquí (clic derecho en la carpeta > Nuevo recurso >
   MiMecanica), ponle `piso_desbloqueo` y guárdalo como
   `mecanica_<nombre>.tres`.

3. Listo. No hay que registrar nada en ningún sitio.

## Mecánicas que hay ahora

| Archivo | Qué hace | Desde el piso |
|---|---|---|
| `objetos.tres` | Deja un objeto recogible por piso | 1 |
| `enemigos.tres` | Reparte enemigos que persiguen al jugador | 2 |
| `rocas_moviles.tres` | Parte de las rocas van y vienen en línea recta | 4 (**desactivada**) |

`rocas_moviles.tres` está con `activa = false` porque a Matías no le convenció
al jugarlo. No se ha borrado: volver a encenderla es cambiar ese flag.

`rocas_moviles.tres` es el ejemplo de que el sistema funciona: no hay ni una
línea suya en `gestor_progreso.gd` ni en `piso.gd`. Para desactivarla, pon
`activa = false` en su `.tres`. Para que empiece en otro piso, cambia
`piso_desbloqueo`. Para que se muevan más o menos rocas, `proporcion_moviles`.
Todo desde el inspector, sin tocar código.
