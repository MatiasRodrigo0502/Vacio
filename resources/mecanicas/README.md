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

La carpeta está vacía en la Fase 1 porque todavía no hay mecánicas concretas:
el sistema funciona igual con cero mecánicas cargadas.
