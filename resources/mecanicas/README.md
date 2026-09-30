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
| `objetos.tres` | Deja un objeto recogible por piso, en el centro de la sala del objeto. Además, cada enemigo que muere tiene un 3 % (`probabilidad_al_matar`) de soltar otro; las crías de slime no | 1 |
| `enemigos.tres` | Reparte enemigos por las salas de pelea: de media 3 por sala en el piso 2 y 0,5 más por piso, hasta 8 en el 12. Como mucho la mitad a distancia. Duermen hasta que entras en su sala | 2 |
| `peligros.tres` | Pinchos que salen a ratos (desde el 2), agujeros por los que caerse (desde el 3) y lava (desde el 4), de 1 a 3 por sala de pelea. Nunca tapan el paso de una puerta al centro de la sala | 2 |
| `rocas_moviles.tres` | Parte de las rocas van y vienen en línea recta | 4 (**desactivada**) |

`rocas_moviles.tres` está con `activa = false` porque a Matías no le convenció
al jugarlo. No se ha borrado: volver a encenderla es cambiar ese flag.

`rocas_moviles.tres` es el ejemplo de que el sistema funciona: no hay ni una
línea suya en `gestor_progreso.gd` ni en `piso.gd`. Para desactivarla, pon
`activa = false` en su `.tres`. Para que empiece en otro piso, cambia
`piso_desbloqueo`. Para que se muevan más o menos rocas, `proporcion_moviles`.
Todo desde el inspector, sin tocar código.
