⬅️ [Volver a Conceptos](README.md)

# Capa Física (Capa 1) — Cobre, fibra óptica, transceptores SFP, negociación y PoE

**Capa OSI principal:** Capa 1 (Física) | **Estándares:** `IEEE 802.3ab/ae`, `IEEE 802.3af/at/bt`, `ANSI/TIA-568`, `SFF-8472 (DDM/DOM)`

---

## 🧠 ¿Qué es?

La **Capa 1 (Física)** es donde los datos dejan de ser software y se convierten en **física pura**: pulsos de voltaje en hilos de cobre, haces de luz láser infrarroja dentro de un hilo de vidrio (fibra óptica) o ondas electromagnéticas en el aire (radiofrecuencia WiFi).

Además de transportar bits, en las redes modernas la Capa 1 también **negocia automáticamente la velocidad y el sentido de transmisión** (*Auto-Negotiation: Speed & Duplex*) y **transporta energía eléctrica continua (48V–57V DC)** por el mismo cable de datos mediante **PoE (*Power over Ethernet*)** para encender cámaras IP, puntos de acceso WiFi y teléfonos VoIP sin enchufes adicionales.

---

## 🎯 ¿Por qué importa en el día a día?

Más del **50% de las fallas "misteriosas"** de red (lentitud intermitente, llamadas cortadas, cámaras que se reinician de noche o enlaces que bajan de 1 Gbps a 100 Mbps) tienen su causa raíz en la Capa 1. Ninguna configuración de firewall, QoS o routing puede arreglar un cable con un par cortado o una fibra sucia.

- **En diseño:** Determina qué medio elegir (cobre hasta 100 metros dentro del piso vs fibra óptica para unir racks, edificios o superar interferencias eléctricas) y cuánta fuente PoE (en Watts) necesita el switch.
- **En operación/mantenimiento:** Te permite prever fallas leyendo por consola la **potencia óptica en `dBm` (DDM/DOM)** de un módulo SFP o la caída de voltaje PoE antes de que el enlace se corte.
- **En troubleshooting:** Si ves el contador de errores **CRC / FCS** subiendo o una interfaz Gigabit negociando a `100Mbps` o `Half-Duplex`, diagnosticás un problema físico en 10 segundos sin perder horas revisando configuraciones lógicas.

---

## ⚙️ Cómo funciona por dentro

### 1. Cobre de par trenzado (UTP / FTP / S/FTP) y la regla de los 4 pares

Un cable de red RJ45 tiene **8 hilos organizados en 4 pares trenzados**. El trenzado cancela la interferencia electromagnética. Lo que todo ingeniero debe saber de memoria es **cuántos pares usa cada tecnología**:

```text
Conector RJ45 (Norma T568B — estándar en instalaciones empresariales):
  Pin 1: Blanco/Naranja  ─┐ Par 2 (TX+ / BI_DA+) ─┐
  Pin 2: Naranja         ─┘                       ├─> Fast Ethernet (10/100 Mbps)
  Pin 3: Blanco/Verde    ─┐ Par 3 (RX+ / BI_DB+) ─┤   SOLO USA ESTOS 2 PARES (Pines 1, 2, 3 y 6)
  Pin 6: Verde           ─┘                       ─┘
  -----------------------------------------------------------------------------
  Pin 4: Azul            ─┐ Par 1 (BI_DC+)       ─┐
  Pin 5: Blanco/Azul     ─┘                       ├─> Gigabit (1000BASE-T), 2.5G, 5G, 10G y PoE
  Pin 7: Blanco/Marrón   ─┐ Par 4 (BI_DD+)       ─┤   EXIGEN LOS 4 PARES COMPLETOS (Pines 1 al 8)
  Pin 8: Marrón          ─┘                       ─┘
```

> **💡 Revelación diagnóstica:** Si una ficha RJ45 tiene mal crimpado el **pin 4, 5, 7 u 8** (o un roedor mordió uno de esos hilos), **el enlace NO se cae a cero**: las placas detectan que los pines 1, 2, 3 y 6 siguen vivos y **bajan automáticamente la velocidad de `1000 Mbps` a `100 Mbps`**. Siempre que veas un enlace Gigabit clavado en `100 Mbps`, tenés un hilo roto en los pares Azul o Marrón.

| Categoría | Velocidad máx. | Distancia máx. | Frecuencia | Blindaje y uso real |
|-----------|----------------|----------------|------------|---------------------|
| **Cat 5e** | `1 Gbps` (`2.5 Gbps` hasta 100m) | `100 m` (90m fijo + 10m patch) | `100 MHz` | Mínimo aceptable para oficinas, cámaras IP y APs básicos |
| **Cat 6** | `1 Gbps` (100m) / `10 Gbps` (55m) | `100 m` (`55 m` a 10G) | `250 MHz` | Estándar actual para cableado estructurado nuevo |
| **Cat 6A** | `10 Gbps` | `100 m` completos | `500 MHz` | Centros de datos, uplinks en cobre y WiFi 6E / WiFi 7 de alto caudal |
| **UTP vs FTP / S/FTP** | Depende de Cat | `100 m` | Variable | **UTP**: sin blindaje (oficinas). **FTP / S/FTP**: con malla/lámina metálica para exteriores, torres de radio o fábricas con motores eléctricos (requiere puesta a tierra) |

> ⚠️ **Cobre puro vs CCA (*Copper Clad Aluminum*):** Nunca uses cable **CCA** (aluminio bañado en cobre). Tiene mucha más resistencia eléctrica, se quiebra al crimpar y provoca una caída de voltaje tan alta que las cámaras PoE a más de 40 metros no encienden o se reinician solas.

### 2. Fibra óptica y transceptores SFP / SFP+ (Leyendo niveles de luz en `dBm`)

Para unir racks a más de 100 metros, pasar a `10 Gbps / 25 Gbps / 40 Gbps / 100 Gbps` o aislar eléctricamente dos edificios contra descargas atmosféricas (rayos), se usa **fibra óptica** conectada mediante módulos **SFP (1G)** o **SFP+ (10G)**:

```text
   [Switch A: Módulo SFP+]                                    [Switch B: Módulo SFP+]
   +---------------------+   Hilo 1: TX (Láser) ---------->   +---------------------+
   | TX Power: -2.5 dBm  | =================================> | RX Power: -4.1 dBm  |
   | RX Power: -4.3 dBm  | <================================= | TX Power: -2.7 dBm  |
   +---------------------+   <---------- Hilo 2: RX (Fotodiodo)+---------------------+
            Conector LC Duplex (o 1 solo hilo en módulos BiDi WDM)
```

| Tipo de Fibra | Núcleo / Revestimiento | Color típico de chaqueta | Transceptor y Longitud de onda | Alcance típico a 10 Gbps |
|---------------|------------------------|--------------------------|--------------------------------|--------------------------|
| **Multimodo (MMF)** `OM3` / `OM4` | `50 / 125 µm` (núcleo ancho, usa LED/VCSEL) | **Aguamarina (Aqua)** o Violeta | `SFP+ SR` (`850 nm` — corto alcance) | `300 m` (`OM3`) a `400 m` (`OM4`) — ideal dentro del mismo Data Center o edificio |
| **Monomodo (SMF)** `OS2` | `9 / 125 µm` (núcleo microscópico, usa láser directo) | **Amarillo** (interior) o Negro (exterior) | `SFP+ LR` (`1310 nm`) / `ER` (`1550 nm`) / `BiDi` (`1270/1330 nm`) | `10 km` (`LR`), `40 km` (`ER`), `80 km` (`ZR`) — estándar entre edificios y campus |
| **Cable DAC (Twinax)** | Cobre pasivo con SFP+ soldados en las puntas | Negro | Direct Attach Copper (sin láser) | `1 m` a `7 m` — el más barato y de menor latencia para unir switches del mismo rack |

#### Cómo interpretar la potencia óptica recibida (`RX Power` en `dBm` vía DDM/DOM)

La escala `dBm` es logarítmica y en recepción siempre se mueve en valores negativos (**cuanto más cerca de `0 dBm`, más fuerte es la luz; cuanto más negativo, más oscura y débil llega la señal**):

- **`0 dBm` a `-3 dBm`:** ⚠️ **Peligro de saturación** (si usás un SFP de largo alcance `ER/ZR 40km` con un patchcord de 2 metros sin atenuador, podés quemar el fotodiodo receptor).
- **`-3 dBm` a `-18 dBm`:** ✅ **Zona óptima de operación** en enlaces `SR` (multimodo) y `LR` (monomodo).
- **`-19 dBm` a `-24 dBm`:** ⚠️ **Señal degradada / Alarma baja** (conector LC sucio con polvo, curva cerrada en el patchcord de fibra o empalme defectuoso).
- **`< -26 dBm` (ej. `-35 dBm` o `-40 dBm`):** ❌ **LOS (*Loss of Signal*)** — No llega luz; hilo de fibra cortado o cruzado (`TX` con `TX`).

### 3. Auto-Negotiation y el desastre del Duplex Mismatch

En Ethernet moderno, ambos extremos deben estar en **`Auto-Negotiation: ON`**. El desastre ocurre cuando alguien fuerza manualmente un extremo a `100 Mbps Full-Duplex` y deja el otro extremo en `Auto`:

- El extremo en `Auto`, al no recibir pulsos de negociación del lado fijo, asume por estándar IEEE que del otro lado hay un Hub viejo y se configura en **`100 Mbps Half-Duplex`**.
- **Resultado (*Duplex Mismatch*):** El enlace figura `UP`, el ping sin carga da `1 ms`, pero apenas copiás un archivo el lado Full transmite sin esperar, el lado Half detecta **Late Collisions** y el lado Full acumula miles de **errores CRC**, desplomando la velocidad real a menos de `1 Mbps`.

### 4. Power over Ethernet (PoE): Estándar Activo vs Pasivo

| Estándar / Tipo | Nombre comercial | Voltaje en puerto | Potencia máx. entregada (PSE) | Potencia útil en el equipo (PD) | Negociación y seguridad |
|-----------------|------------------|-------------------|-------------------------------|---------------------------------|-------------------------|
| **`IEEE 802.3af`** | **PoE** (Tipo 1) | `44–57V DC` | `15.4 W` | `12.95 W` | ✅ **Activo:** mide resistencia (`25 kΩ`) antes de inyectar voltaje. Seguro para PCs no-PoE |
| **`IEEE 802.3at`** | **PoE+** (Tipo 2) | `50–57V DC` | `30.0 W` | `25.5 W` | ✅ **Activo:** cámaras domo PTZ, puntos de acceso WiFi 6 empresariales |
| **`IEEE 802.3bt`** | **PoE++** (Tipo 3 / 4) | `50–57V DC` | `60 W` (T3) / `100 W` (T4) | `51 W` / `71.3 W` | ✅ **Activo (usa los 4 pares):** cámaras térmicas con calefactor, switches alimentados por PoE |
| **PoE Pasivo** | *Passive PoE 24V / 48V* | `24V` o `48V` fijo | Variable (`12W–24W`) | Variable | ❌ **Sin negociación (Siempre encendido):** típico en antenas MikroTik/Ubiquiti WISP. **Si enchufás una PC o equipo no compatible a un puerto 24V pasivo forzado, podés quemar su placa de red** |

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto Capa 1 | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `ethtool`) |
|-----------------|----------------------|----------------------|----------------------------|--------------------------------|
| **Ver estado físico, velocidad y duplex** | `show interfaces Gi1/0/1` / `show interfaces status` | `/interface ethernet monitor ether1 once` | `show interfaces brief` | `ethtool eth0` |
| **Ver contadores de errores físicos (CRC/FCS)** | `show interfaces counters errors` | `/interface ethernet print stats` | `show interfaces 1` (`FCS / Alignment`) | `ethtool -S eth0` / `ip -s link show eth0` |
| **Diagnóstico de cable por reflectometría (TDR)** | `test cable-diagnostics tdr interface Gi1/0/1` + `show cable-diagnostics tdr` | `/interface ethernet cable-test ether1` | `test cable-diagnostics 1` | `ethtool --cable-test eth0` |
| **Lectura óptica del SFP (DDM / DOM en dBm)** | `show interfaces Gi1/0/25 transceiver detail` | `/interface ethernet monitor sfp-sfpplus1 once` | `show interfaces transceiver 25 detail` | `ethtool -m eth0` |
| **Estado y consumo PoE por puerto** | `show power inline` / `show power inline detail` | `/interface ethernet poe monitor ether1` | `show power-over-ethernet brief` | SNMP OID `1.3.6.1.2.1.105` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Velocidad en puerto Gigabit (`1000BASE-T`)** | `1Gbps` / `Full-Duplex` | `100Mbps` (con `auto-negotiation: done`) | Hilo roto o pin sulfatado en el par **Azul (4–5)** o **Marrón (7–8)** del cable UTP o patch panel |
| **Contadores `FCS / CRC Errors` y `Runts`** | `0` (o valor congelado en el tiempo) | Sube constantemente con el tráfico | Interferencia EMI (cable UTP pegado a motores/trifásica), ficha RJ45 mal crimpada o cable > 100 metros |
| **Contadores `Late Collisions` / `Deferred`** | `0` siempre en redes con switches | `> 0` creciendo de un lado y `CRC` del otro | **Duplex Mismatch**: un extremo fue forzado manualmente a `Full` y el otro cayó a `Half` |
| **Potencia óptica SFP (`sfp-rx-power`)** | `-3.0 dBm` a `-16.0 dBm` estable | `< -24.0 dBm` o `-40.0 dBm` (`rx-los: yes`) | Fibra óptica estrangulada/quebrada, polvo en férula LC o hilos TX/RX conectados al revés |
| **Estado PoE (`poe-out-status`)** | `powered-on`, voltaje `48V–54V`, corriente estable | `short-circuit`, `overload` o reinicios cíclicos | Agua en ficha exterior RJ45 (corto), consumo mayor al estándar del puerto o presupuesto total del switch agotado |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Mezclar SFP Monomodo (`LR 1310nm`, tirador azul) con Fibra Multimodo (naranja/aqua) o viceversa:** El núcleo monomodo mide `9 µm` y el multimodo `50 µm`. Aunque el conector `LC` encaja físicamente, el acoplamiento de luz falla y el enlace se cae a los pocos metros o sufre pérdidas masivas.
- **❌ Mirar un conector de fibra óptica de frente con el ojo desnudo para ver "si sale luz roja":** Los transceptores de fibra real (`850 nm`, `1310 nm`, `1550 nm`) emiten **luz láser infrarroja invisible para el ojo humano** que puede dañar la retina sin que sientas reflejo de parpadeo. Nunca mires la punta de una fibra activa; leé los `dBm` por consola con DDM/DOM o usá un medidor óptico.
- **❌ Conectar los dos extremos de un patchcord de fibra nueva sin cruzar `TX` con `RX`:** El láser transmisor (`TX`) del Switch A debe entrar al fotodiodo receptor (`RX`) del Switch B. Si un enlace de fibra recién instalado no levanta (`Link Down`), el primer intento siempre es destrabar el clip plástico del conector `LC` en una de las puntas e invertir los dos hilos (`A ↔ B`).
- **❌ Forzar velocidad y duplex manualmente "para que sea más estable":** En Gigabit Ethernet (`1000BASE-T`), la autonegociación es obligatoria para acordar el reloj maestro/esclavo (`Master/Slave clock`). Dejá siempre `Auto-Negotiation` activo en ambos lados salvo en casos puntuales de transceptores ópticos antiguos que exijan desactivarlo en ambos extremos por igual.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

En un depósito logístico se instalan **12 cámaras IP PoE** exteriores en un switch PoE de 16 puertos (`150W` de presupuesto total). Durante el día todas las cámaras funcionan perfecto, pero **todas las noches a las 19:30 hs, 3 cámaras siempre se apagan y entran en un bucle de reinicio constante** hasta el amanecer.

### Análisis paso a paso por capas

1. **Síntoma observado:** Caída simultánea y predecible de 3 cámaras únicamente en horario nocturno.
2. **Hipótesis usando el modelo mental (Capa 1 — Presupuesto PoE y caída de tensión):**
   - ¿Qué cambia físicamente en una cámara de seguridad a las 19:30 hs cuando oscurece? **Se encienden los reflectores LED infrarrojos (IR) de visión nocturna** y el calefactor desempañador.
   - De día, cada cámara consume apenas `4.5 W` (`12 × 4.5 W = 54 W`, muy por debajo de los `150 W` del switch). De noche, con los IR al máximo, cada cámara pasa a pedir `14 W` (`12 × 14 W = 168 W`).
3. **Evidencia que lo confirma:**
   - Entramos al switch (`show power inline` en Cisco / `/interface ethernet poe monitor` en MikroTik) a las 19:35 hs: vemos el presupuesto consumido al límite (`149.8 W / 150 W`) y en los logs aparece **`%ILPOWER-5-ILPOWER_POWER_DENY`** (o `poe-out: overload`).
   - El switch, al quedarse sin watts disponibles en su fuente interna, **corta la alimentación de los puertos de menor prioridad** (por defecto, los puertos con número más alto: bocas 14, 15 y 16).
4. **Resolución arquitectónica:**
   - Configuramos prioridad PoE `critical/high` en las cámaras perimetrales críticas, movemos 4 cámaras a un segundo switch PoE (o agregamos inyectores PoE+ dedicados para las domo PTZ de mayor consumo) dejando siempre un **margen de seguridad del 20%** sobre el consumo máximo nocturno (`Max Watts × 1.2`).

---

## 🧠 Modelo mental

Pensá en esto como **las rutas de asfalto y la red eléctrica sobre las que circulan los camiones de reparto (Capa 2)**:

- **Un cable UTP Cat6** es una autopista de **4 carriles**: si una tormenta rompe uno solo de los carriles (se corta el hilo 7 o 8), la policía vial cierra el tránsito pesado de alta velocidad (`1 Gbps`) y desvía a todos por los 2 carriles viejos a velocidad reducida (`100 Mbps`).
- **Los errores CRC** son baches profundos en el pavimento: los camiones llegan al depósito destino con la mercadería rota, el guardia de recepción ve que el remito no coincide con la carga y **tira el camión entero a la basura** pidiendo que lo manden de nuevo desde cero.
- **El PoE activo (`802.3af/at`)** es un enchufe inteligente que primero toca la puerta y pregunta *"¿necesitás 48 voltios?"* antes de mandar corriente, mientras que el **PoE pasivo** es una manguera de electricidad abierta las 24 horas que electrocuta a cualquiera que no esté preparado para recibirla.

---

## 🧪 Autoevaluación rápida (Active Recall)

Respondé mentalmente antes de desplegar cada respuesta; si dudás, volvé a la sección correspondiente del documento.

**1. Si una ficha RJ45 tiene mal crimpado el pin 4 (par Azul) pero los pines 1, 2, 3 y 6 están bien, ¿por qué el enlace no se cae a cero y en cambio queda clavado en `100 Mbps`?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Fast Ethernet (10/100 Mbps) solo usa los pines 1, 2, 3 y 6 (dos pares). Gigabit Ethernet y PoE exigen los 4 pares completos. Al faltar uno de los pares Azul/Marrón, la autonegociación detecta que solo puede sostener dos pares y degrada el enlace a `100 Mbps` en lugar de dejarlo caído. Síntoma clásico: un puerto Gigabit fijo en `100 Mbps`.

</details>

**2. Un módulo SFP de fibra reporta `rx-power: -25 dBm`. ¿Qué indica ese valor y en qué punto pasás a `LOS`?**

<details>
<summary>👀 Ver respuesta explicada</summary>

La escala `dBm` es negativa: cuanto más cerca de `0`, más luz. La zona óptima es `-3` a `-18 dBm`; `-19` a `-24` avisa señal degradada (férula sucia, curva cerrada, empalme malo). Por debajo de `-26 dBm` (por ejemplo `-40 dBm`) hay `LOS` (*Loss of Signal*): fibra cortada o hilos `TX`/`RX` invertidos.

</details>

**3. ¿Por qué un `Duplex Mismatch` deja el enlace `UP` y con ping normal, pero hunde la velocidad real a menos de `1 Mbps`?**

<details>
<summary>👀 Ver respuesta explicada</summary>

Ocurre cuando un extremo se fuerza manualmente a `Full-Duplex` y el otro queda en `Auto`. El lado `Auto`, al no recibir pulsos de negociación, asume por estándar `100 Mbps Half-Duplex`. El lado Full transmite sin escuchar, el lado Half detecta `Late Collisions` y el lado Full acumula errores `CRC`, destruyendo el rendimiento con cargas reales aunque el ping ocioso dé `1 ms`.

</details>

---

## 🔗 Ver también

- [`how-to-think-like-network-engineer`](how-to-think-like-network-engineer.md) — Cómo empezar siempre el diagnóstico verificando las señales de Capa 1
- [`osi-and-tcp-ip-models`](osi-and-tcp-ip-models.md) — Cómo los bits de Capa 1 se transforman en tramas Ethernet de Capa 2
- [`ethernet-mac-and-arp`](ethernet-mac-and-arp.md) — Qué viaja inmediatamente arriba del cable: tramas Ethernet, direcciones MAC y tabla CAM
