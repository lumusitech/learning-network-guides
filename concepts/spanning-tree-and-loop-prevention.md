⬅️ [Volver a Conceptos](README.md)

# Spanning Tree (STP / RSTP) y Prevención de Bucles — Cómo un solo cable tira toda una empresa

**Capa OSI principal:** Capa 2 (Enlace de Datos) | **Estándares:** `IEEE 802.1D (STP)`, `IEEE 802.1w (RSTP)`, `IEEE 802.1s (MSTP)`, `Cisco PVST+/Rapid-PVST+`

---

## 🧠 ¿Qué es?

En cualquier red crítica queremos redundancia: si el cable entre el switch principal y el switch del Piso 2 se corta, queremos tener un segundo cable de respaldo listo para actuar. El problema es que en **Capa 2 (Ethernet)** no podés simplemente conectar dos cables en paralelo o cerrar un anillo entre switches: si lo hacés sin un protocolo de control, creás un **bucle de Capa 2 (*Layer 2 Loop*)** que satura y derriba toda la red en menos de **3 segundos**.

El protocolo **Spanning Tree (`STP` / `RSTP`)** resuelve esta paradoja: permite que conectes cables físicos redundantes entre switches, descubre automáticamente dónde se forma un anillo enviando mensajes de saludo (**BPDUs**) cada 2 segundos, y **pone en pausa lógica (*Blocked / Alternate*) el puerto redundante** para que la topología activa sea un árbol sin bucles. Si el cable principal se corta, RSTP despierta el puerto bloqueado en milisegundos sin intervención humana.

---

## 🎯 ¿Por qué importa en el día a día?

Un bucle de Capa 2 es el incidente más violento que existe en una red local: cuando ocurre, todas las luces de todos los switches parpadean fijas al unísono, el ping al gateway sube a `2.000 ms` o da timeout, se caen los teléfonos IP y ni siquiera podés entrar por SSH a los switches porque su CPU está al **100%**.

- **En diseño:** Si dejás la prioridad de Spanning Tree en su valor de fábrica (`32768`), el protocolo elige como **jefe de toda tu red (*Root Bridge*) al switch con la dirección MAC más vieja** (¡que suele ser un switch viejo de 8 puertos olvidado debajo de un escritorio!), haciendo que todo el tráfico del edificio dé una vuelta absurda por ese switch chico.
- **En operación/mantenimiento:** Configurar **PortFast / Edge Port + BPDU Guard** en todas las bocas de usuarios evita que un empleado tire la empresa cuando conecta un cable suelto entre dos rosetas de pared.
- **En troubleshooting:** Si ves en los logs **`MAC Flapping`** (la misma MAC saltando entre dos puertos) y uso de CPU disparado en los switches, tenés un bucle de Capa 2 activo y sabés exactamente qué puerto desconectar.

---

## ⚙️ Cómo funciona por dentro

### 1. ¿Por qué un bucle en Capa 2 es mortal mientras que en Capa 3 no?

Recordá el encabezado de las capas:

- Un **Paquete IP (Capa 3)** tiene un campo llamado **`TTL` (*Time to Live*)**. Si hay un bucle de rutas entre dos routers, el paquete da 64 vueltas, su `TTL` llega a `0` y el router lo destruye.
- Una **Trama Ethernet (Capa 2)** **NO TIENE CAMPO TTL**. Si entra en un anillo entre switches, gira infinitamente a la velocidad de la luz hasta que alguien desenchufe el cable.

Peor aún: cuando una PC envía un simple **`ARP Request` en Broadcast (`FF:FF:FF:FF:FF:FF`)**, ocurren tres desastres simultáneos en un anillo de switches:

```text
           [PC-1 envía 1 solo ARP Broadcast]
                          |
                          v
                   +--------------+
                   |   SWITCH A   |
                   +--------------+
                  /                \
      Sale copia 1                  Sale copia 2
      por Puerto 1                  por Puerto 2
                /                    \
               v                      v
        +------------+          +------------+
        |  SWITCH B  | <======> |  SWITCH C  |
        +------------+  Cable   +------------+
                        en bucle
```

1. **Tormenta de Broadcast (*Broadcast Storm*):** El Switch A inunda el broadcast por sus puertos 1 y 2. El Switch B se lo manda al C, y el C se lo manda de vuelta al A, que lo vuelve a inundar al B. En milisegundos, **un solo paquete se multiplica exponencialmente** hasta ocupar el 100% del ancho de banda (`1 Gbps` / `10 Gbps`) de todos los enlaces.
2. **Inestabilidad de la Tabla MAC (*MAC Table Flapping*):** Como la trama con la `MAC Origen` de `PC-1` ahora le entra al Switch B primero por la izquierda y un microsegundo después por la derecha, la tabla CAM del switch reescribe miles de veces por segundo la ubicación de cada MAC hasta colapsar la CPU.
3. **Multiplicación de tramas duplicadas:** El destinatario final recibe miles de copias idénticas del mismo paquete, corrompiendo cualquier sesión TCP.

---

### 2. Cómo RSTP (`802.1w`) construye un árbol libre de bucles en 3 pasos

Los switches se envían tramas especiales de control llamadas **BPDUs (*Bridge Protocol Data Units*)** a la MAC multicast `01:80:C2:00:00:00` cada **2 segundos (`Hello Time`)**:

```text
               +---------------------------------------+
               |       SWITCH CORE (ROOT BRIDGE)       |
               |   Prioridad: 4096 (0x1000) — ¡EL JEFE!|
               |   Pto 1: DESIGNATED | Pto 2: DESIGNATED
               +---------------------------------------+
                       /                       \
         Enlace 1Gbps /                         \ Enlace 1Gbps
         (Costo = 4) /                           \ (Costo = 4)
                    v                             v
      Pto 1: ROOT PORT                    Pto 1: ROOT PORT
    +--------------------+              +--------------------+
    |   SWITCH PISO 1    |              |   SWITCH PISO 2    |
    |  Prioridad: 32768  |              |  Prioridad: 32768  |
    |  MAC: AA:AA:AA:01  |              |  MAC: BB:BB:BB:02  |
    +--------------------+              +--------------------+
     Pto 2: DESIGNATED (FWD) <=========> Pto 2: ALTERNATE / BLOCKED (¡Corta el bucle!)
                              Cable redundante
```

1. **Paso 1 — Elegir un único jefe supremo (*Root Bridge Election*):**
   - Cada switch anuncia su **Bridge ID**, compuesto por: **`Prioridad (2 bytes)` + `Dirección MAC (6 bytes)`**.
   - **Gana el switch que tenga el número MÁS BAJO.**
   - Como todos los switches de todas las marcas vienen de fábrica con la misma **`Prioridad = 32768` (`0x8000`)**, si vos no la cambiás, empatan en prioridad y **desempata la dirección MAC más baja** (¡el switch más viejo de la empresa!).
   - **Regla profesional obligatoria:** Siempre tenés que configurar manualmente a tu Switch Core principal con **`Prioridad = 4096` (`0x1000`)** y a tu Switch Core secundario con **`Prioridad = 8192` (`0x2000`)**.
2. **Paso 2 — Elegir en cada switch secundario su *Root Port* (`RP`):**
   - Cada switch que no es Root elige **un único puerto** que tiene el camino más corto y rápido (menor *Root Path Cost* según la velocidad del enlace) para llegar al Root Bridge. Ese puerto se llama **Root Port** y siempre reenvía tráfico (`Forwarding`).
3. **Paso 3 — Elegir el *Designated Port* (`DP`) de cada cable y bloquear el resto (`Alternate / Blocked`):**
   - En cada cable entre dos switches, el extremo que está más cerca del Root Bridge queda como **Designated Port (`Forwarding`)** y el extremo opuesto del cable redundante se pone en estado **Alternate / Discarding (Bloqueado)**: **no deja pasar tráfico de usuarios (cortando el bucle), pero sigue escuchando BPDUs**. Si el enlace principal cae, ese puerto bloqueado pasa a `Forwarding` en `< 1 segundo` con RSTP.

### Anatomía / Componentes clave y Timers

| Concepto / Timer | Valor Estándar | Función real | Qué pasa si está mal |
|------------------|----------------|--------------|----------------------|
| **Bridge Priority** | `32768` (`0x8000`) por defecto (múltiplos de `4096`, de `0` a `61440`) | Define quién será el Root Bridge (gana el menor valor: `4096` le gana a `32768`) | Si queda en `32768` en todos lados, un switch de acceso viejo puede convertirse en el centro de toda la red |
| **STP Clásico (`802.1D`) vs RSTP (`802.1w`)** | `STP`: tarda **30 a 50 seg** (`20s MaxAge + 15s Listening + 15s Learning`). `RSTP`: **`< 1 seg`** | RSTP negocia activamente entre switches vecinos (*Proposal/Agreement*) sin esperar timers pasivos | Nunca uses STP `802.1D` clásico hoy: un corte de 50 segundos tira todas las sesiones de base de datos, llamadas e iSCSI |
| **PortFast / Edge Port** | Desactivado por defecto en puertos | Le dice al switch: *"En esta boca solo va conectada una PC final, no otro switch: pasá a `Forwarding` al instante sin esperar"* | Si no activás `PortFast / Edge` en bocas de PCs, cuando la PC arranca rápido por SSD, el puerto sigue bloqueado 30s por STP y **la PC falla al pedir IP por DHCP** |
| **BPDU Guard** | Protección de puertos Edge | Si un puerto de usuario (`PortFast / Edge`) recibe una trama BPDU (porque enchufaron un switch o armaron un bucle), **apaga el puerto en el acto (`err-disabled`)** | Sin `BPDU Guard`, un bucle en una oficina de 4 personas puede dejar sin red a todo el edificio |

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto STP / RSTP | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / Ubiquiti / TP-Link | Linux (`bridge` / `mstpd`) |
|---------------------|----------------------|----------------------|----------------------------|----------------------------|
| **Modo del protocolo activo** | `spanning-tree mode rapid-pvst` (por VLAN) o `mst` | En `/interface bridge`: `protocol-mode=rstp` (o `mstp`) | `spanning-tree force-version rstp-operation` | `ip link set br0 type bridge stp_state 1` |
| **Fijar el Switch Core como Root Bridge (`4096`)** | `spanning-tree vlan 1-4094 priority 4096` (o `root primary`) | `/interface bridge set bridge1 priority=0x1000` (`4096` en hex) | `spanning-tree priority 1` (`1 × 4096 = 4096`) | `ip link set br0 type bridge priority 4096` |
| **Ver quién es el Root y estados de puertos** | `show spanning-tree` | `/interface bridge monitor bridge1` + `/interface bridge port monitor [find]` | `show spanning-tree` | `bridge link show` / `mstpctl showbridge` |
| **Puerto inmediato para PCs (sin demora DHCP)** | `spanning-tree portfast` | En `/interface bridge port`: `edge=yes` (o `auto`) | `spanning-tree 1-20 admin-edge-port` | `bridge link set dev eth1 fastleave on` |
| **Apagar boca si detecta switch o bucle abajo** | `spanning-tree bpduguard enable` (+ `loopback-detection`) | En `/interface bridge port`: `bpdu-guard=yes` y en ethernet `loop-protect=on` | `spanning-tree 1-20 bpdu-protection` + `loop-protect 1-20` | `bridge link set dev eth1 guard on` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Identidad del Root Bridge (`Root ID`)** | Todos los switches de la empresa muestran como `Root ID` la MAC de tu Switch Core (`Prioridad 4096`) | El `Root ID` apunta a una MAC desconocida con prioridad `32768` a través de un puerto de piso | Nadie fijó la prioridad del Core y un switch recién enchufado con MAC más baja ganó la elección de Root Bridge |
| **Contador de cambios de topología (`Topology Change Count` / `TCN`)** | Muy bajo; último cambio hace días o semanas | El contador `TCN` sube cada pocos minutos y la red sufre microcortes | **Falta `PortFast / Edge` en los puertos de PCs:** cada vez que un empleado prende o apaga su computadora, el switch cree que cambió la topología de red y purga las tablas MAC de todo el edificio |
| **Puerto en estado `err-disabled (bpduguard)` o `loop-protect: disabled`** | Todos los puertos activos en `Forwarding` (`FWD`) | Una boca de oficina se apaga sola y el log reporta `BPDU Guard violation` o `loop detected` | ✅ **La protección funcionó:** alguien en esa boca conectó un cable entre dos puertos o enchufó un switch en bucle. El switch aisló la boca culpable salvando al resto de la red |
| **LEDs de todos los switches parpadeando fijos a máxima velocidad** | Parpadeo irregular suave siguiendo el tráfico normal | Todos los LEDs parecen luces fijas, CPU al 100%, ping al gateway `> 1000 ms` o `Request timed out` | **Tormenta de Broadcast por bucle L2 activo** en un switch que tenía STP desactivado (`protocol-mode=none`) o en un switch doméstico bobo (*unmanaged*) cuyos dos cables no ven BPDUs |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Desactivar Spanning Tree (`protocol-mode=none` / `no spanning-tree`) porque "nosotros no conectamos cables redundantes":** Spanning Tree no está solo para tus enlaces de rack; está para protegerte del día en que un usuario bienintencionado ve un patchcord suelto sobre la mesa de reuniones y lo enchufa en la roseta de pared de al lado. **Jamás desactives RSTP en un switch de producción.**
- **❌ Confiar solo en `BPDU Guard` para frenar un bucle dentro de un switch doméstico no gestionable (*"switch bobo"*):**
  - Atención a esta sutileza técnica: si un usuario conecta un switch económico TP-Link/Mercusys de 5 puertos a la boca de pared `Gi1/0/10` y luego conecta **un cable entre el puerto 2 y el puerto 3 de ese mismo switch chiquito**, ese switch doméstico **no genera BPDUs** y a veces ni siquiera devuelve la BPDU del switch grande hacia arriba antes de saturarse con su propia tormenta de broadcast.
  - Por eso, además de `BPDU Guard`, en los puertos de acceso siempre conviene activar **`Loop Protect` / `Loopback Detection`** y **Storm Control (límite de broadcast al 5–10% del puerto)**.
- **❌ Olvidar que en MikroTik la prioridad de RSTP se escribe en hexadecimal (`0x1000` = `4096`, `0x2000` = `8192`, `0x8000` = `32768`):** Si escribís un valor que no sea múltiplo de `4096` (`0x1000`), el estándar IEEE 802.1w lo rechazará.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Un viernes a las 16:00 hs se cae por completo la red de una clínica de 3 pisos. Nadie puede abrir historias clínicas, las llamadas VoIP se cortan y el router principal apenas responde 1 de cada 10 pings con `1.800 ms` de latencia. En el rack central, todos los switches tienen todos sus LEDs verdes parpadeando a velocidad frenética como si estuvieran fijos.

### Análisis paso a paso por capas

1. **Síntoma observado:** Colapso simultáneo de toda la LAN con LEDs saturados al 100% de actividad. Es la firma inconfundible de una **Tormenta de Broadcast por bucle de Capa 2**.
2. **Hipótesis usando el modelo mental (Aislar la rama del árbol donde nace la tormenta):**
   - Entramos por cable de consola serie (porque el SSH se corta por la saturación) al Switch Core.
   - Miramos las estadísticas de tráfico en tiempo real por puerto (`show interfaces counters rate` en Cisco / `/interface print stats` en MikroTik) y los logs de *MAC Flapping*.
3. **Evidencia que lo confirma:**
   - El log escupe sin parar: `%SW_MATM-4-MACFLAP_NOTIF: Host 00:11:22:33:44:55 in vlan 10 is flapping between port Gi1/0/1 and port Gi1/0/3`.
   - El puerto `Gi1/0/3` (que va hacia el switch de Recepción) está recibiendo **`940 Mbps` de tráfico Broadcast puro**.
   - Apagamos temporalmente `Gi1/0/3` (`shutdown`). **Instantáneamente en 1 segundo la clínica entera recupera el sistema, el ping baja a `0.3 ms` y los pisos 1, 2 y 3 vuelven a trabajar.**
   - Vamos a Recepción: habían movido un teléfono IP (que tiene 2 puertos RJ45 traseros: `SW` hacia la pared y `PC` hacia la computadora) y conectaron tanto la ficha `SW` como la ficha `PC` del teléfono a dos bocas de la pared. Como el switch de Recepción era un switch viejo con STP desactivado, armaron un puente directo entre dos puertos de la VLAN 10.
4. **Resolución arquitectónica:**
   - Desconectamos el cable sobrante en el teléfono IP, activamos **RSTP** en todos los switches, fijamos al Switch Core como Root Bridge (`priority 4096`), y habilitamos `PortFast/Edge + BPDU Guard + Loop Protect + Storm Control (Broadcast 5%)` en todas las bocas de usuario.

---

## 🧠 Modelo mental

Pensá en esto como **un sistema de micrófonos y parlantes en un salón de actos**:

- **Un bucle de Capa 2 sin Spanning Tree** es poner el micrófono pegado frente al parlante: el menor murmullo que entra al micrófono (**un solo paquete Broadcast ARP**) sale amplificado por el parlante, vuelve a entrar al micrófono más fuerte, vuelve a salir por el parlante a toda potencia y en 2 segundos tenés un **acople ensordecedor (*Broadcast Storm*)** que aturde a todo el salón y no deja que nadie escuche a nadie.
- **Spanning Tree (RSTP)** es el sonidista automático que mide todos los micrófonos cada 2 segundos (**BPDUs**): elige la consola central como referencia (**Root Bridge**) y, si detecta que dos cables forman un circuito cerrado de acople, **pone en `Mute` (*Alternate / Blocked*)** uno de los dos canales, dejándolo listo para quitarle el `Mute` en una fracción de segundo si el micrófono principal se corta.
- **BPDU Guard / Loop Protect** es el fusible en las tomas del escenario: si alguien del público intenta enchufar un parlante donde solo debía ir un auricular, salta la térmica de esa sola toma (`err-disabled`) sin apagarle el sonido a todo el teatro.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. ¿Por qué un bucle de rutas en Capa 3 se detiene solo, mientras que un bucle en Capa 2 entre switches puede tumbar toda la red?**

<details>
<summary>👀 Ver respuesta explicada</summary>

El paquete IP (Capa 3) tiene el campo `TTL`: tras dar las vueltas del bucle llega a `0` y el router lo descarta. La trama Ethernet (Capa 2) **no tiene TTL**, así que gira infinitamente. Un solo `ARP Request` en broadcast se reenvía por todos los puertos del anillo y se multiplica exponencialmente hasta saturar el ancho de banda (*Broadcast Storm*) y provocar *flapping* de la tabla MAC.

</details>

**2. Todos los switches están en su prioridad de fábrica `32768`. ¿Quién gana la elección de Root Bridge y cómo lo evitás en producción?**

<details>
<summary>👀 Ver respuesta explicada</summary>

A igual prioridad, el Bridge ID desempata por la **dirección MAC más baja**, que suele ser el switch más viejo de la empresa. La regla profesional es fijar manualmente el Switch Core con prioridad `4096` (`0x1000`) y el Core secundario con `8192` (`0x2000`). En MikroTik se escribe en hexadecimal: `priority=0x1000`.

</details>

**3. ¿Qué rol cumplen `PortFast / Edge Port` y `BPDU Guard` en una boca de usuario, y qué pasa si falta cada uno?**

<details>
<summary>👀 Ver respuesta explicada</summary>

`PortFast / Edge` pasa el puerto a `Forwarding` al instante, evitando que la PC espere ~30 s por STP y falle el pedido de IP por DHCP. `BPDU Guard` apaga (`err-disabled`) el puerto si recibe una BPDU, es decir si alguien enchufó un switch o armó un bucle. Sin PortFast hay demoras al arrancar; sin BPDU Guard, un bucle en una sola oficina puede dejar sin red a todo el edificio.

</details>

---

## 🔗 Ver también

- [`ethernet-mac-and-arp`](ethernet-mac-and-arp.md) — Por qué el Flooding de tramas Broadcast y Unknown Unicast dispara las tormentas cuando hay un bucle
- [`vlans-tagged-untagged-and-trunks`](vlans-tagged-untagged-and-trunks.md) — Cómo interactúa Spanning Tree con las VLANs (RSTP único vs Rapid-PVST+ por VLAN vs MSTP)
- [`link-aggregation-and-redundancy-l2`](link-aggregation-and-redundancy-l2.md) — Cómo conectar 2 o 4 cables entre dos switches y usar todos a la vez **sin** que Spanning Tree bloquee ninguno (LACP 802.3ad)
