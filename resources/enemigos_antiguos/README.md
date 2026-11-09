# resources/enemigos_antiguos/

Los enemigos que había hasta el 2026-11-04, cuando Matías los cambió por los de
`vacio_completo.zip`: slime verde, naranja y de magma, rata, serpiente, planta
venenosa, murciélago, gólem de roca, fantasma y planta azul. **Ya no salen**: la
mecánica de enemigos solo lee `resources/enemigos/`. El **cristal vivo** ha vuelto
(2026-11-09, Matías): está en `resources/enemigos/cristal_vivo.tres`, con su dibujo
nuevo de la rama `enemigos-antiguos-8-direcciones`.

Se guardan aquí, con su arte en `assets/enemigos/` y sus comportamientos en
`scripts/comportamientos/`, porque siguen funcionando: **para que uno vuelva a
salir, basta con moverlo a `resources/enemigos/`**. `Enemigo` sabe pintar los de una
sola animación (`moverse`, y se voltean). Comprobado con el slime verde: anima y
suelta sus cuatro crías, que heredan lo que le quedaba a la madre.

Saldría en todos los pisos desde su `piso_minimo`, salvo que se le ponga un
`piso_maximo`.
