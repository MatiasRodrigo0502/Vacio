# resources/enemigos_antiguos/

Los once enemigos que había hasta el 2026-11-04, cuando Matías los cambió por los
de `vacio_completo.zip`: slime verde, naranja y de magma, rata, serpiente, planta
venenosa, murciélago, gólem de roca, cristal vivo, fantasma y planta azul. **Ya no
salen**: la mecánica de enemigos solo lee `resources/enemigos/`.

Se guardan aquí, con sus comportamientos en `scripts/comportamientos/`, porque
siguen funcionando: **para que uno vuelva a salir, basta con moverlo a
`resources/enemigos/`**.

**Desde el 2026-11-06 tienen dibujo nuevo**, como los del paquete: vectorial, en
las 8 direcciones y con `caminar`, `atacar`, `dano` y `muerte`. Lo hace
`herramientas/generar_antiguos.py`, que lo deja en `assets/criaturas/antiguo_<id>/`
y escribe aquí `escala_dibujo` y `desfase_dibujo`. Se ven del mismo tamaño que
antes. Matías los quería ver antes de decidir si vuelven, así que siguen aquí.

Antes de que vuelvan: los de cuerpo a cuerpo con comportamiento propio (saltos,
zigzag, rebote, excavar, fantasma, pisotón, teletransporte) no llaman a
`Enemigo.gesto(&"atacar")`; sin eso andan y mueren bien, pero no se les ve atacar.
Los de distancia sí (lo hace `Enemigo.pelear_a_distancia`).

El dibujo de antes (una tira de 10 poses que se volteaba) sigue en
`assets/enemigos/`: para volver a él, apuntar el `.tres` a su
`animaciones_<id>.tres` y quitar `escala_dibujo` y `desfase_dibujo`.

Saldría en todos los pisos desde su `piso_minimo`, salvo que se le ponga un
`piso_maximo`.
