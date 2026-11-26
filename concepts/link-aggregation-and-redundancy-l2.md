⬅️ [Volver a Conceptos](README.md)

# Agregación de Enlaces (LACP / 802.3ad) — Redundancia y ancho de banda sin bucles

**Capa OSI principal:** Capa 2 (Enlace de Datos) | **Estándares:** `IEEE 802.3ad`, `IEEE 802.1AX (LACP)`

---

## 🧠 ¿Qué es?

En el documento anterior vimos que si conectás dos cables entre el Switch A y el Switch B para tener más velocidad o respaldo, **Spanning Tree (RSTP) bloquea uno de los dos cables** para evitar un bucle mortal, dejándote con la velocidad de un solo cable (`1 Gbps`).

La **Agregación de Enlaces (*Link Aggregation* / `LAG`)** mediante el estándar **IEEE 802.3ad / 802.1AX (LACP — *Link Aggregation Control Protocol*)** resuelve esto: toma 2, 4 u 8 puertos físicos paralelos entre dos equipos y los fusiona para que tanto el switch como Spanning Tree los vean como **un único tubo lógico (`Port-channel` / `Bond`)**. Así usás todos los cables al mismo tiempo sumando capacidad total y, si un cable se corta, el tráfico sigue fluyendo por los demás en milisegundos sin recalcular Spanning Tree.

---

## 🎯 ¿Por qué importa en el día a día?

Los enlaces troncales entre switches (o entre un switch y un servidor de virtualización Proxmox/VMware o un NAS) son el cuello de botella de cualquier red. Si tenés 24 usuarios a `1 Gbps` y un solo cable de `1 Gbps` subiendo al servidor, todos compiten por esa única cañería.

- **En diseño:** Te permite crear uplinks de `2 Gbps`, `4 Gbps` o `20 Gbps` con redundancia física real antes de dar el salto a cambiar toda la electrónica por puertos de fibra más caros.
- **En operación/mantenimiento:** Entender la **trampa de nombres entre fabricantes** (especialmente en **HP/Aruba**, donde la palabra **`Trunk`** significa **LACP** y no VLAN Trunk) evita que destruyas la conectividad al conectar switches de distintas marcas.
- **En troubleshooting:** Te explica por qué, aunque armes un LACP de `4 × 1 Gbps = 4 Gbps`, cuando copiás un archivo desde **una sola PC a un solo servidor** la velocidad máxima sigue siendo **`1 Gbps`** (y por qué eso es el comportamiento correcto del estándar por diseño).

---

## ⚙️ Cómo funciona por dentro

### 1. Cómo LACP fusiona varios puertos físicos en una sola interfaz lógica

Sin LACP, Spanning Tree ve dos caminos separados y bloquea uno. Con LACP, ambos switches intercambian tramas de control **LACPDUs** (a la MAC multicast `01:80:C2:00:00:02`), verifican que los cables conecten a los mismos dos equipos con idénticos parámetros y presentan hacia las capas superiores **una única interfaz virtual (`Port-channel1` / `bond1`)**:

```text
SIN LACP (RSTP bloquea 1 cable):                   CON LACP 802.3ad (Ambos cables activos):
+----------+  Cable 1: 1G (FWD)   +----------+     +----------+   +================+   +----------+
|          |--------------------->|          |     |          |===| Cable 1 (1Gbps)|===|          |
| SWITCH A |                      | SWITCH B |     | SWITCH A |   | Port-channel 1 |   | SWITCH B |
|          |-----X (BLOCKED)------|          |     |          |===| Cable 2 (1Gbps)|===|          |
+----------+  Cable 2: 0G usados  +----------+     +----------+   +================+   +----------+
  Capacidad útil total = 1 Gbps                      Capacidad agregada total = 2 Gbps + Failover
```

### 2. Modos de negociación LACP (La matriz de compatibilidad)

Para que un enlace agregado se forme sin peligro de crear un bucle si alguien enchufa un cable en el puerto equivocado, **siempre debemos usar el protocolo dinámico estándar LACP (`802.3ad`)** y nunca el modo estático forzado (`mode on`):

| Modo en Lado A | Modo en Lado B | ¿Se forma el LAG? | Cómo funciona la negociación |
|----------------|----------------|:-----------------:|------------------------------|
| **`Active`** (LACP activo) | **`Active`** (LACP activo) | ✅ **SÍ (Recomendado)** | Ambos lados envían LACPDUs activamente preguntando *"¿querés armar un grupo conmigo?"*. Es la configuración más rápida y segura |
| **`Active`** (LACP activo) | **`Passive`** (LACP pasivo) | ✅ **SÍ** | El lado `Passive` escucha en silencio y solo responde cuando el lado `Active` le habla primero |
| **`Passive`** (LACP pasivo) | **`Passive`** (LACP pasivo) | ❌ **NO** | Ambos esperan en silencio a que el otro hable primero; nunca negocian |
| **`On`** (Estático / Sin protocolo) | **`Active`** o **`Passive`** | ❌ **NO (¡Peligro de bucle o pérdida!)** | El lado `On` manda tráfico a ciegas sin hablar LACP; el lado `Active` no recibe LACPDUs y suspende o desagrupa los puertos |

### 3. El mito de la velocidad: Cómo funciona el algoritmo de Hash (Balanceo por flujo)

Esta es la pregunta clásica de todo administrador: *"Armé un LACP de 2 cables de 1 Gbps entre el switch y el servidor NAS. Hago una prueba con `iperf3` (un solo hilo) o copio un ISO desde mi PC al NAS y no pasa de `1 Gbps` (`112 MB/s`). ¿Está roto el LACP?"*

**No está roto.** El estándar IEEE 802.3ad **prohíbe dividir los paquetes de una misma conversación TCP por dos cables distintos**, porque si el paquete #2 llegara un microsegundo antes que el paquete #1 por el otro cable, TCP detectaría paquetes desordenados (*Out-of-Order packets*) y desplomaría el rendimiento pidiendo retransmisiones.

En su lugar, el switch calcula una fórmula matemática (**Hash XOR**) sobre las cabeceras de cada paquete para elegir **un cable fijo para cada conversación**:

```text
  [PC-1: 10.0.10.51] ──┐                                ┌──(Hash = Par -> Cable 1: 1 Gbps)──>┐
  [PC-2: 10.0.10.52] ──┼──> [Switch: Algoritmo Hash] ───┤                                    ├──> [Servidor NAS]
  [PC-3: 10.0.10.53] ──┤     (src-dst-ip + puertos L4)  └──(Hash = Impar -> Cable 2: 1 Gbps)─┘    (Recibe 2 Gbps
  [PC-4: 10.0.10.54] ──┘                                                                           sumados!)
```

### Anatomía de las Políticas de Hash (*Transmit Hash Policy*)

| Algoritmo de Hash | Qué campos mira para elegir el cable | Cuándo sirve y cuándo falla |
|-------------------|--------------------------------------|-----------------------------|
| **`layer-2` (`src-dst-mac`)** | Solo `MAC Origen` y `MAC Destino` | Sirve entre dos switches con muchas PCs en la misma VLAN. **Falla si hay un Router en el medio** (porque todos los paquetes que vienen del router traen siempre la misma MAC del router y van todos por un solo cable) |
| **`layer-2-and-3` (`src-dst-ip`)** | `MAC` + `IP Origen` e `IP Destino` | Balancea bien cuando muchas PCs distintas hablan con varios servidores, incluso cruzando routers |
| **`layer-3-and-4` (`ip-and-ports`)** | `IP Origen/Destino` + `Puerto TCP/UDP Origen/Destino` | ✅ **El más eficiente:** si una misma PC abre 4 conexiones TCP distintas hacia el mismo servidor (puertos origen `50101`, `50102`, `50103`, `50104`), cada conexión puede viajar por un cable distinto del LACP |

---

## 🔄 Diccionario Multi-Vendor (¡Cuidado con la trampa de nombres!)

Prestá especial atención a la primera fila: **tres marcas usan palabras distintas para lo mismo, y HP/Aruba usa la palabra `"Trunk"` para LACP**:

| Concepto Estándar (`802.3ad`) | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / HP ProCurve | Linux (`iproute2` / `bonding`) |
|-------------------------------|----------------------|----------------------|---------------------|--------------------------------|
| **Nombre de la interfaz agregada (LAG)** | **EtherChannel** / `interface Port-channel 1` (`Po1`) | **Bonding** / `/interface bonding` (`bond1`) | **Trunk** (`trk1`) *(¡En Aruba "Trunk" es LACP, no VLAN!)* | **Bonding** (`bond0`) / `team0` |
| **Activar LACP estándar (`802.3ad`)** | `channel-group 1 mode active` | `mode=802.3ad` | `trunk 1-2 trk1 lacp` | `mode=802.3ad` (`mode=4`) + `lacp_rate=fast` |
| **Elegir política de balanceo (Hash)** | `port-channel load-balance src-dst-mixed-ip-port` | `transmit-hash-policy=layer-3-and-4` | `trunk-load-balance L4-based` | `xmit_hash_policy=layer3+4` |
| **Ver estado de los cables del grupo** | `show etherchannel summary` / `show lacp neighbor` | `/interface bonding monitor bond1` | `show trunks` / `show lacp` | `cat /proc/net/bonding/bond0` |
| **Dónde se configuran las VLANs del enlace** | En la interfaz lógica `interface Port-channel 1` | Agregando `bond1` (nunca `ether1/2` sueltos) a `/interface bridge port` y `bridge vlan` | Sobre la interfaz lógica `trk1` (`vlan 10 tagged trk1`) | Creando subinterfaces `bond0.10` o metiendo `bond0` al bridge |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Flags de los puertos miembros en Cisco (`show etherchannel summary`)** | `Po1(SU)` con todos sus puertos en **`P`** (*Bundled in port-channel*) | Un puerto aparece con flag **`I`** (*Stand-alone*), **`s`** (*Suspended*) o **`D`** (*Down*) | **`I`**: el otro extremo no tiene LACP configurado. **`s`**: el puerto tiene diferente VLAN, velocidad o modo trunk que sus hermanos |
| **Puertos activos en MikroTik (`/interface bonding monitor`)** | `active-ports: ether1,ether2` y flag **`H`** (*Hw-Offload*) en el bridge port | `active-ports: ether1` (falta `ether2`) o desaparece el flag `H` y la CPU sube al 90% | Si falta un puerto: fallo LACP o cable roto. Si desaparece `H` en un switch CRS3xx: el bonding no fue agregado al bridge o usa un modo no soportado por el chip |
| **Distribución de tráfico entre los cables miembros** | Con decenas de usuarios activos, ambos cables muestran tráfico repartido (ej. `45% / 55%`) | Hay 100 usuarios pasando por un Router y el Cable 1 va al `99%` mientras el Cable 2 va al `1%` | **Política de Hash en `layer-2` (`src-dst-mac`):** como todo el tráfico viene de la misma MAC del router, el hash da siempre el mismo resultado. Cambiar a `layer-3-and-4` |
| **Pérdida exacta del 50% de los pings** | `0%` packet loss; si desconectás un cable se pierde a lo sumo 1 ping | Se pierde exactamente 1 de cada 2 paquetes o la mitad de las PCs no tienen red | Un extremo fue configurado en **modo estático (`mode on` / `balance-rr`)** y el otro extremo no (o un cable del par está conectado a un tercer switch equivocado) |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Configurar las VLANs en el puerto físico `ether1` en vez de en la interfaz lógica `bond1` / `Port-channel1`:** Una vez que `ether1` y `ether2` pasan a ser esclavos (*slaves*) de un grupo LACP, **dejan de existir como puertos independientes para las capas superiores**. Toda configuración de VLANs (`tagged`, `untagged`, `pvid`), Spanning Tree o dirección IP debe aplicarse **exclusivamente sobre `bond1` o `interface Port-channel1`**.
- **❌ Usar `mode=balance-rr` (*Round-Robin*) en MikroTik o Linux creyendo que es mejor porque suma los 2 Gbps en una sola descarga:** El modo `balance-rr` manda el paquete 1 por el cable A y el paquete 2 por el cable B sin hablar LACP. En la vida real, si lo conectás contra un switch gestionable normal ocasiona bucles o desorden masivo de paquetes TCP (*Out-of-Order*), y si un cable falla sin caer el link eléctrico, perdés la mitad del tráfico. **En producción entre switches y servidores se usa siempre `802.3ad` (LACP).**
- **❌ Conectar los dos cables de un LACP común a dos switches distintos que no están en Stack/MLAG:** Para que un switch o servidor arme un LACP `802.3ad`, **del otro lado tiene que responder un único System-ID LACP** (es decir, el mismo switch físico, o dos switches empresariales unidos por tecnología de *Stacking / vPC / MLAG*). Si enchufás el cable 1 al Switch A y el cable 2 al Switch B independientes usando `802.3ad`, LACP detectará que son dos switches distintos y **suspenderá uno de los dos cables**. (Para redundancia activa/pasiva hacia dos switches independientes sin MLAG, se usa el modo `active-backup`).

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Un administrador quiere duplicar el ancho de banda entre el switch core **Cisco Catalyst** y el nuevo switch de distribución **Aruba 2530**. Conecta dos cables Gigabit entre `Gi1/0/23-24` del Cisco y los puertos `23-24` del Aruba. En el Cisco configura `switchport mode trunk` y `channel-group 1 mode on` (estático). En el Aruba no toca nada de LACP, solo pone las VLANs 10 y 20 como `Tagged` en los puertos 23 y 24. A los 5 segundos, el piso entero empieza a sufrir cortes y pérdida del 50% de los paquetes.

### Análisis paso a paso por capas

1. **Síntoma observado:** Pérdida masiva de paquetes apenas se enchufa el segundo cable del supuesto enlace agregado.
2. **Hipótesis usando el modelo mental (Falta de negociación LACP por usar `mode on`):**
   - El Cisco, al estar en `mode on` (forzado sin protocolo LACP), **apagó la negociación LACP** y empezó a escupir la mitad de las tramas por el puerto 23 y la otra mitad por el puerto 24 creyendo que el Aruba sabía que eran un grupo.
   - El Aruba, como nadie le configuró un grupo (`trunk 23-24 trk1 lacp`), ve los puertos 23 y 24 como **dos cables sueltos en paralelo**; su Spanning Tree (RSTP) entra en pánico al ver un bucle y **bloquea el puerto 24**, tirando a la basura el 50% de los paquetes que el Cisco sigue mandando por ese cable.
3. **Evidencia que lo confirma:**
   - En el Aruba, `show spanning-tree` muestra el puerto `23` en `Forwarding` y el puerto `24` en `Blocked`.
   - En el Cisco, `show etherchannel summary` muestra `Po1(SU)` con `Gi1/0/23(P)` y `Gi1/0/24(P)` porque el modo `on` nunca chequea si el vecino está vivo o bloqueado.
4. **Resolución arquitectónica:**
   - En el Aruba agrupamos los puertos con LACP estándar y aplicamos las VLANs a la interfaz lógica `trk1`: `trunk 23-24 trk1 lacp`, seguido de `vlan 10 tagged trk1` y `vlan 20 tagged trk1`.
   - En el Cisco eliminamos el peligroso `mode on` y pasamos a LACP activo: `channel-group 1 mode active`, aplicando `switchport mode trunk` sobre `interface Port-channel1`.
   - Verificamos con `show lacp` en ambos lados: los dos puertos negocian LACPDUs, Spanning Tree ve a `Po1 ↔ trk1` como un único enlace lógico en `Forwarding` y la pérdida cae a `0%`.

---

## 🧠 Modelo mental

Pensá en esto como **ampliar un puente de 1 solo carril a una autopista de 4 carriles entre dos ciudades (`LACP 802.3ad`)**:

- **Si un auto deportivo (una sola conexión TCP)** cruza la autopista de 4 carriles, **¿puede viajar a 400 km/h ocupando los 4 carriles a la vez?** No: un solo auto sigue viajando por un único carril a la velocidad máxima de ese carril (`100 km/h` = `1 Gbps`).
- **¿Cuál es entonces la ventaja enorme de los 4 carriles?** Que ahora pueden cruzar **400 autos al mismo tiempo repartidos en los 4 carriles (`4 Gbps` de caudal total)** sin formar embotellamiento en el peaje, y si un carril se cierra por obras (se corta un cable), la cabina de peaje inteligente (**el algoritmo de Hash LACP**) desvía instantáneamente a los autos hacia los otros 3 carriles abiertos sin que la autopista se cierre ni un segundo.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Armás un LACP `802.3ad` de 4 × 1 Gbps, copiás un ISO de una PC al servidor y no pasa de `112 MB/s`. ¿Está roto el enlace?**

<details>
<summary>👀 Ver respuesta explicada</summary>

No. El estándar **prohíbe repartir los paquetes de una misma conversación TCP** por cables distintos, porque llegarían desordenados (*Out-of-Order*) y TCP pediría retransmisiones. El algoritmo de **Hash** asigna un cable fijo por flujo: una sola conversación usa 1 Gbps, pero muchas conversaciones en paralelo suman los 4 Gbps.

</details>

**2. Ponés LACP `Passive` en ambos extremos del enlace. ¿Se forma el grupo? ¿Por qué?**

<details>
<summary>👀 Ver respuesta explicada</summary>

No se forma. Los dos lados quedan en silencio esperando que el otro envíe LACPDUs primero, así que nunca negocian. Necesitás al menos un extremo en **`Active`** (`Active`+`Active` o `Active`+`Passive`) para que arranque el intercambio de LACPDUs a `01:80:C2:00:00:02`.

</details>

**3. En un Cisco configurás `channel-group 1 mode on` y en el Aruba no tocás LACP. El piso pierde el 50% de los paquetes. ¿Cuál es la causa raíz?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El `mode on` es **estático sin protocolo**: el Cisco manda la mitad de las tramas por cada puerto a ciegas. El Aruba ve dos cables sueltos en paralelo, RSTP detecta el bucle y bloquea un puerto, tirando el 50% del tráfico. Se corrige pasando el Cisco a `mode active` y agrupando el Aruba con `trunk 23-24 trk1 lacp`.

</details>

---

## 🔗 Ver también

- [`spanning-tree-and-loop-prevention`](spanning-tree-and-loop-prevention.md) — Por qué sin LACP Spanning Tree bloquea los cables paralelos para evitar tormentas
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — Cómo transportar múltiples VLANs (`802.1Q`) por encima de una interfaz lógica `Port-channel / bond1 / trk1`
- [`ipv4-addressing-subnetting-and-vlsm`](ipv4-addressing-subnetting-and-vlsm.md) — El paso siguiente: subir de Capa 2 (Switching) a Capa 3 (Direccionamiento IP y Subredes)
