# Guía de Demostración de la Red Hyperledger Besu (QBFT)

En este documento se describe el procedimiento para demostrar el funcionamiento de una red blockchain privada basada en Hyperledger Besu y el algoritmo de consenso QBFT. La demostración permite comprobar el registro de transacciones, la tolerancia a fallos mediante la caída de nodos validadores y la recuperación automática de la red.

---

## 1. Fundamento Teórico del Quórum

El protocolo **QBFT** implementa un mecanismo de consenso tolerante a fallos bizantinos basado en la teoría clásica de PBFT (Castro & Liskov, 1999).

La tolerancia a fallos viene determinada por el número total de validadores de la red:

$$F = \left\lfloor \frac{N - 1}{3} \right\rfloor$$

Donde:

- $N = 4$: número de validadores iniciales.
- $F = \lfloor (4 - 1)/3 \rfloor = 1$: número máximo de fallos tolerables.
- Quórum mínimo para sellar bloques: $2F + 1 = 2(1) + 1 = \mathbf{3\text{ validadores}}$.

Por tanto, con cuatro validadores, la red puede seguir generando bloques si uno de ellos deja de estar disponible. Sin embargo, si dos validadores caen simultáneamente, los dos restantes no alcanzan el quórum necesario y la producción de bloques se detiene.

La siguiente tabla resume el comportamiento esperado:

| Validadores activos | Situación | ¿Se alcanza el quórum? | Resultado esperado |
| :---: | :--- | :---: | :--- |
| 4 | Estado inicial | Sí (4 ≥ 3) | La red funciona con normalidad. |
| 3 | Caída de 1 validador | Sí (3 ≥ 3) | La red continúa generando bloques y confirmando transacciones. |
| 2 | Caída de 2 validadores | No (2 < 3) | La producción de bloques se detiene y las transacciones no se confirman. |
| 3 | Recuperación de 1 validador | Sí (3 ≥ 3) | La red reanuda el consenso y puede confirmar las transacciones pendientes. |
| 4 | Recuperación de todos los validadores | Sí (4 ≥ 3) | La red vuelve a su estado inicial. |

---

## 2. Demostración del Funcionamiento Normal

### Fase 1. Estado Estable Inicial

Tras realizar el despliegue de la topología de red para realizar las comprobaciones prácticas debemos:
1. Abrir el explorador **Chainlens** en la dirección `http://localhost:8081`

2. Acceder a `Blockchain > Blocks` y comprobar que la altura de bloque se incrementa de forma continua, aproximadamente cada 5 segundos.

### Fase 2. Envío de una Transacción desde MetaMask

Una vez comprobado que la red funciona con normalidad, se realiza una transferencia de prueba entre dos cuentas.

1. Abrir la extensión de **MetaMask** y seleccionar la cuenta **Magnate**.

2. Pulsar en `Enviar`, seleccionar ETH como activo e introducir los siguientes datos:

   - **Destinatario:** dirección de la cuenta Plebeyo, `0x36D1446EBA1F8e36EF6Baf2175fdfd583a682D55`.
   - **Divisa:** Ethereum
   - **Cantidad:** 10 ETH.

3. Confirmar la transacción en MetaMask.

4. Una vez confirmada, volver a Chainlens y acceder a `Blockchain > Blocks`. Localizar uno de los bloques generados después del envío y comprobar que contiene la transacción realizada.

5. Entrar en los detalles del bloque. Entre la información mostrada se encuentran el tamaño del bloque, su hash y las transacciones incluidas. En los detalles de la transferencia se puede comprobar que:

   - La dirección de origen corresponde a la cuenta Magnate.
   - La dirección de destino corresponde a la cuenta Plebeyo.
   - La cantidad transferida es de 10 ETH.

6. Esta misma información también está disponible en `Blockchain > Transactions`. Al abrir la transacción, el campo `Status` debe indicar que la operación se ha completado correctamente (`Succeeded`).

7. Finalmente, volver a MetaMask para comprobar el cambio en los saldos:

   - **Magnate:** su saldo disminuye en 10 ETH, además de la comisión de la transacción.
   - **Plebeyo:** su saldo aumenta en 10 ETH.

   En la ejecución de laboratorio realizada, Magnate queda con un saldo de 89.990 ETH y Plebeyo dispone de 10 ETH.

**Resultado esperado:** la transacción se registra en un bloque, queda confirmada por el consenso QBFT y se actualizan los saldos de ambas cuentas.

---

## 3. Prueba de Resiliencia con un Validador Caído

### Fase 3. Detención del Validador 1

En esta fase se comprueba que la red puede continuar operando a pesar de perder uno de sus cuatro validadores.

1. Detener el primer validador:

   ```bash
   docker stop quorum-test-network-validator1-1
   ```

2. Esperar unos instantes y comprobar en Chainlens que la red continúa generando bloques. Puede ser necesario esperar al siguiente turno de consenso o a un cambio de ronda (`Round Change`).

3. Realizar una nueva transferencia desde Magnate hacia Plebeyo siguiendo el procedimiento descrito en la fase anterior.

4. Comprobar en MetaMask que la transacción se confirma y que los saldos se actualizan correctamente.

5. Acceder a `Blockchain > Network` en Chainlens y comprobar que el campo `Peer Count` muestra 3 nodos validadores activos.

### Resultado observado

La caída del primer validador no impide el funcionamiento de la red. Quedan tres validadores activos y se cumple la condición de quórum:

$$N_{\text{activos}} = 3 \geq 2F + 1 = 3$$

Por tanto, la red conserva el número mínimo de validadores necesario para alcanzar el consenso. Aunque puede ser necesario un cambio de ronda si el nodo caído debía proponer el siguiente bloque, la producción de bloques continúa y las transacciones pueden confirmarse con normalidad.

**Conclusión:** el comportamiento observado valida la tolerancia a la caída de un validador prevista para una red QBFT con cuatro validadores.

---

## 4. Prueba de Resiliencia con Dos Validadores Caídos

### Fase 4. Detención del Validador 2

En esta fase se comprueba qué ocurre cuando la red pierde un segundo validador y deja de disponer de suficientes nodos para alcanzar el quórum.

1. Manteniendo detenido el validador 1, detener también el validador 2:

   ```bash
   docker stop quorum-test-network-validator2-1
   ```

2. Esperar a que la red deje de producir nuevos bloques. En Chainlens, dentro de `Blockchain > Blocks`, comprobar que la altura de bloque permanece constante.

3. Desde MetaMask, intentar realizar una nueva transferencia desde Magnate hacia Plebeyo.

4. Comprobar en la sección `Actividad` de MetaMask que la transacción permanece en estado pendiente (`Pending`).

5. Revisar nuevamente Chainlens para verificar que no se han generado nuevos bloques que incluyan la transacción.

### Resultado observado

Tras detener dos validadores, únicamente quedan activos el validador 3 y el validador 4. En esta situación no se alcanza el quórum requerido:

$$N_{\text{activos}} = 2 < 2F + 1 = 3$$

Los dos validadores restantes no pueden reunir las tres participaciones necesarias para completar el consenso. Por este motivo, la red deja de sellar bloques y las nuevas transacciones no pueden confirmarse.

La transacción enviada desde MetaMask queda pendiente a la espera de que se restablezcan las condiciones necesarias para alcanzar el consenso.

**Conclusión:** al caer dos de los cuatro validadores, la red pierde disponibilidad para confirmar nuevas transacciones. Este comportamiento es coherente con el límite de tolerancia a fallos de QBFT en una red de estas características.

---

## 5. Recuperación del Consenso y de la Red

### Fase 5. Reactivación del Validador 2

Para recuperar la capacidad de alcanzar el consenso, se vuelve a poner en marcha uno de los validadores que estaban detenidos.

1. Reactivar el validador 2:

   ```bash
   docker start quorum-test-network-validator2-1
   ```

2. Esperar a que el nodo se reincorpore a la red y se restablezca la comunicación entre los validadores.

3. Comprobar en Chainlens que la producción de bloques se reanuda y que la altura de bloque vuelve a incrementarse.

4. Volver a MetaMask y acceder a la sección `Actividad`. Comprobar que la transacción que había quedado pendiente se confirma una vez recuperado el quórum.

5. Acceder a `Blockchain > Transactions` en Chainlens y localizar la transacción para verificar que se ha incluido en la blockchain y que su estado es exitoso (`Succeeded`).

### Resultado observado

Con la recuperación del validador 2, vuelven a estar activos tres validadores. Por tanto, se recupera el quórum mínimo necesario para continuar el consenso:

$$N_{\text{activos}} = 3 \geq 2F + 1 = 3$$

La red reanuda la producción de bloques y, en la ejecución de laboratorio realizada, la transacción que estaba pendiente se confirma tras la recuperación.

**Conclusión:** la reactivación de un validador permite recuperar el quórum, reanudar el consenso y procesar la transacción que había quedado pendiente durante la interrupción.

### Fase 6. Recuperación del Validador 1

Una vez comprobada la recuperación de la red, se vuelve a activar el primer validador para restablecer la configuración inicial.

1. Reactivar el validador 1:

   ```bash
   docker start quorum-test-network-validator1-1
   ```

2. Esperar a que el nodo se reincorpore a la red y se sincronice con los bloques generados durante su ausencia.

3. Comprobar en Chainlens que la red vuelve a disponer de sus cuatro validadores y que continúa generando bloques.

4. Verificar que las transacciones realizadas durante la demostración aparecen en `Blockchain > Transactions` con el estado correspondiente.

**Resultado esperado:** los cuatro validadores vuelven a estar activos y la red recupera su configuración inicial, manteniendo el historial de bloques y transacciones generado durante las pruebas.

---

## 6. Resumen de Resultados

Las pruebas permiten comprobar experimentalmente la relación entre el número de validadores disponibles y la capacidad de la red para alcanzar el consenso QBFT.

| Prueba realizada | Validadores activos | Resultado |
| :--- | :---: | :--- |
| Funcionamiento normal | 4 | La red genera bloques y confirma transacciones. |
| Caída del validador 1 | 3 | La red mantiene el consenso y confirma nuevas transacciones. |
| Caída de los validadores 1 y 2 | 2 | No se alcanza el quórum y la producción de bloques se detiene. |
| Reactivación del validador 2 | 3 | Se recupera el quórum y la red reanuda la confirmación de transacciones. |
| Reactivación del validador 1 | 4 | Todos los validadores vuelven a estar activos y la red recupera su estado inicial. |

En conclusión, la demostración confirma que una red Hyperledger Besu configurada con QBFT y cuatro validadores puede tolerar la caída de un nodo sin interrumpir la confirmación de transacciones. Sin embargo, cuando dos validadores dejan de estar disponibles, los restantes no alcanzan el quórum necesario y el consenso se detiene hasta que se recupera al menos uno de los nodos.
