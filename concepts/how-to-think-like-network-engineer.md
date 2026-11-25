⬅️ [Volver a Conceptos](README.md)

# Cómo pensar como un ingeniero de redes — Diagnóstico por capas y operación segura

**Capa OSI principal:** Capas 1–7 (Transversal) | **Estándares:** `ITIL / NetOps`, `RFC 2544`, `IEEE 802`

---

## 🧠 ¿Qué es?

Pensar como un ingeniero de redes (**NetOps**) no consiste en saber de memoria 500 comandos de Cisco o MikroTik, sino en **entender el camino físico y lógico que recorre un paquete de principio a fin** y aislar en minutos en qué salto y en qué capa se detuvo.

Cuando una red falla, el principiante entra al router principal y empieza a tocar reglas de firewall, reiniciar interfaces o cambiar rutas al azar ("probar a ver si levanta"). El ingeniero profesional divide la red en **tres planos independientes** (Datos, Control y Gestión), aplica un **embudo por capas (L1 → L7)** y cambia **una sola variable a la vez** con un salvavidas de rollback activo.

---

## 🎯 ¿Por qué importa en el día a día?

La red es el sistema nervioso de toda la infraestructura: si te equivocás en una línea de configuración de un switch o router remoto, **cortás tu propio acceso SSH** y dejás incomunicada una planta entera o una sucursal a 400 kilómetros.

- **En diseño:** Te obliga a separar el tráfico de administración (*Management*) del tráfico de usuarios y a eliminar puntos únicos de falla antes de poner el equipo en producción.
- **En operación/mantenimiento:** Evita que un cambio rutinario de VLAN o firewall termine en un corte total gracias al uso sistemático de *Safe Mode* (MikroTik) o *reload programado* (Cisco) y backups en texto plano antes de tocar nada.
- **En troubleshooting:** Reduce el tiempo medio de diagnóstico (MTTD) de horas a menos de 5 minutos al descartar capas enteras con una sola prueba.

---

## ⚙️ Cómo funciona por dentro

### 1. Los 3 Planos de todo equipo de red

Todo switch gestionable, router o firewall opera simultáneamente en tres planos separados. Distinguir cuál de los tres está fallando es la primera pregunta de cualquier diagnóstico:

```text
+-----------------------------------------------------------------------+
| 3. PLANO DE GESTIÓN (Management Plane)                                |
|    SSH, WinBox, WebFig, HTTPS, Consola Serie (RS-232), SNMP, Syslog   |
|    Pregunta: "¿Puedo entrar a administrar y monitorear el equipo?"    |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
| 2. PLANO DE CONTROL (Control Plane — CPU del equipo)                  |
|    ARP, STP/RSTP, LACP, OSPF, BGP, VRRP/HSRP, DHCP, LLDP/CDP         |
|    Pregunta: "¿El equipo aprende rutas, MACs y arma la topología?"    |
+-----------------------------------------------------------------------+
                                   |Programa la tabla en hardware (FIB/CAM)
                                   v
+-----------------------------------------------------------------------+
| 1. PLANO DE DATOS (Data / Forwarding Plane — ASIC / Switch Chip)      |
|    Conmutación de tramas L2, reenvío de paquetes L3, NAT, colas QoS   |
|    Pregunta: "¿Los paquetes de los usuarios cruzan de un puerto a otro?"|
+-----------------------------------------------------------------------+
```

### Anatomía / Componentes clave

| Componente / Plano | Dónde se ejecuta | Función real | Qué pasa si está mal |
|--------------------|------------------|--------------|----------------------|
| **Plano de Datos (Forwarding)** | ASIC / Switch Chip (o FastPath en CPU) | Mueve millones de paquetes por segundo consultando tablas ya calculadas (CAM y FIB) | Pérdida de paquetes, baja velocidad o tráfico que no pasa aunque el router responda al ping |
| **Plano de Control** | CPU principal y memoria RAM | Ejecuta protocolos (OSPF, STP, ARP) para decidir cuál es el mejor camino y poblar las tablas | CPU al 100%, caída de vecinos OSPF/BGP, bucles L2 porque STP no procesa BPDUs a tiempo |
| **Plano de Gestión** | Procesos de usuario en CPU (`sshd`, `snmpd`, `www`) | Permite al administrador configurar y leer métricas del equipo | No podés entrar por SSH o WinBox, pero los usuarios siguen navegando normalmente |

### 2. Las 4 metodologías de diagnóstico de red

Un ingeniero elige la estrategia según el síntoma reportado:

1. **Bottom-Up (De Capa 1 a Capa 7):** Empezás revisando enlace físico (LED, SFP, errores CRC) → Capa 2 (MAC/ARP/VLAN) → Capa 3 (IP/Ruta/Ping al gateway) → Capa 4 (Puerto TCP/Firewall/NAT) → Capa 7 (DNS/HTTP). Es la más segura cuando **"nada funciona"** o acabás de cablear un equipo.
2. **Top-Down (De Capa 7 a Capa 1):** Empezás en la aplicación (`curl`, `dig`). Útil cuando el usuario dice **"puedo navegar por YouTube, pero no abre el sistema ERP interno"** (sabés de entrada que las Capas 1, 2 y 3 locales están sanas).
3. **Divide and Conquer (Bisección en Capa 3):** Empezás con un `ping` o `traceroute` a mitad de camino (por ejemplo, al Default Gateway o al extremo remoto del túnel VPN).
   - Si el ping al gateway responde, **descartás inmediatamente** Capa 1, Capa 2 (VLAN/Switch local) y configuración IP de la PC. El problema está del router hacia afuera.
   - Si el ping al gateway falla, el problema está entre la placa de red, el cable, la VLAN del switch y la interfaz LAN del router.
4. **Follow-the-Path (Seguir el paquete salto a salto):** Te parás en el origen y seguís el flujo exacto: `PC → Puerto Access Switch → Puerto Trunk Switch → Interfaz VLAN Router → Tabla de Rutas → Regla Firewall FORWARD → Regla NAT → WAN`.

### 3. Regla de oro en mantenimiento: El Salvavidas Anti-Bloqueo

Nunca modifiques VLANs en el puerto por el que estás conectado, reglas de firewall `INPUT` o rutas hacia tu IP de administración sin activar antes el mecanismo de reversión automática del fabricante:

```text
[Ingeniero por SSH] ---> Aplica cambio de VLAN/Firewall
                              |
              +---------------+---------------+
              |                               |
     ¿Seguís con acceso?             ¿Perdiste conexión?
              |                               |
             SÍ                              NO
              |                               |
   Confirmás y guardás              El timer expira (o cae la sesión)
   en memoria no volátil            y el equipo REVIERTE SOLO al estado
                                    anterior sin que tengas que viajar
```

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto Operativo | Cisco IOS / Catalyst | MikroTik RouterOS | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `bridge`) |
|--------------------|----------------------|-------------------|----------------------------|-------------------------------|
| **Salvavidas ante pérdida de acceso** | `reload in 10` (cancela con `reload cancel`) | **Safe Mode** (`Ctrl+X` en CLI o botón en WinBox) | `reload in` (Aruba CLI) / Test Configuration (UniFi) | `at now + 5 minutes` restaurando backup o `iptables-apply` |
| **Configuración activa en RAM** | `running-config` (`show running-config`) | Configuración activa inmediata en cada menú (`/export`) | Running Config | Estado vivo del kernel (`ip addr`, `nft list ruleset`) |
| **Guardar para sobrevivir a un reinicio** | `copy running-config startup-config` (`write memory`) | Automático (escribe en disco al instante salvo en Safe Mode) | `write memory` / Botón *Save Config* arriba a la derecha | Archivos persistentes (`/etc/network/interfaces`, Netplan) |
| **Aceleración por hardware L2/L3** | CEF (Cisco Express Forwarding) + ASIC | `H` flag (`hw-offload=yes`) + FastTrack / FastPath | Hardware Switching / Offload | Switchdev / eBPF / XDP |
| **Descubrimiento de vecinos directos** | CDP (propietario) y LLDP (`show cdp/lldp neighbors`) | MNDP + CDP + LLDP (`/ip neighbor print`) | LLDP (`show lldp info remote-device`) | `lldpd` (`lldpcli show neighbors`) |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Errores físicos de puerto (CRC / FCS / Alignment)** | `0` (o contador estático sin crecer durante días) | Creciendo cada segundo al pasar tráfico | Cable UTP mal crimpado, par roto, fibra sucia, o **Duplex Mismatch** (un lado Full y otro Half) |
| **Velocidad negociada del enlace** | `1Gbps Full-Duplex` (o `10Gbps Full`) | `100Mbps` o `10Mbps Half-Duplex` en un puerto Gigabit | Uno de los 4 pares del cable UTP (pines 4, 5, 7 u 8) está cortado; Fast Ethernet solo usa 2 pares (1, 2, 3 y 6) |
| **CPU del Switch o Router** | `< 30%` en operación normal; tráfico L2 conmutado por chip | `80% – 100%` sostenido | Bucle de Capa 2 (tormenta de broadcast), pérdida de Hardware Offload (el tráfico pasa por CPU) o ataque a servicios abiertos en WAN |
| **Latencia (RTT) al Default Gateway en LAN cableada** | `< 1 ms` estable, `0%` packet loss | Saltos a `20–150 ms` o pérdida intermitente del `2–10%` | Saturación del enlace trunk, bucle parcial STP, conflicto de IP con el gateway o cola QoS descartando paquetes |
| **Cambios de estado del puerto (Link Flaps / Last Link Up)** | Semanas o meses sin caer | Sube y baja varias veces por hora | Fuente o presupuesto PoE insuficiente, cable excediendo 100 metros o ahorro de energía EEE (802.3az) incompatible |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Creer que "si responde el ping, la red está bien":** El `ping` solo valida que **ICMP en Capa 3** llega y vuelve con paquetes pequeños (normalmente 56/64 bytes). Podés tener un problema de **MTU** que descarta paquetes de 1500 bytes, un firewall bloqueando el puerto **TCP 443** en Capa 4, o el **DNS** roto en Capa 7.
- **❌ Cambiar 3 cosas a la vez durante un incidente:** Si tocás la VLAN del switch, agregás una regla de NAT y reiniciás el módem del ISP al mismo tiempo, cuando vuelva el servicio **no vas a saber qué estaba roto** (y probablemente dejaste una configuración sucia que fallará mañana).
- **❌ Confiar en que la configuración en un switch web ya quedó guardada para siempre:** En switches TP-Link JetStream, Cisco CBS/SG350 o Aruba, cuando aplicás un cambio en la web solo se modifica la `running-config` en RAM. Si a los 3 meses se corta la luz y no hiciste clic en **Save Config / Write Memory**, el switch arranca con la configuración vieja de hace 3 meses.
- **❌ Hacer cambios remotos sin `Safe Mode` o `reload in`:** Es la causa número 1 de viajes de urgencia innecesarios a sitios remotos.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Una empresa reporta a las 09:00 AM que **"ninguna PC del Piso 2 tiene Internet ni acceso al servidor de archivos, pero el Piso 1 trabaja normal"**. El switch del Piso 2 (`SW-PISO2`, Aruba) se conecta por un cable trunk al switch principal (`SW-CORE`, Cisco) y de ahí al router de borde (MikroTik).

### Análisis paso a paso por capas

1. **Síntoma observado:** Aislamiento total de un piso completo. Antes de revisar firewalls o el proveedor de Internet (que ya sabemos que funciona porque el Piso 1 navega), acotamos el dominio de falla al enlace `SW-CORE ↔ SW-PISO2`.
2. **Hipótesis usando el modelo mental (Divide & Conquer + Bottom-Up):**
   - Probamos `ping` desde el router MikroTik a la IP de gestión del `SW-PISO2` (`10.0.99.12`). **No responde.**
   - Entramos por SSH al `SW-CORE` (Cisco) y miramos el puerto `Gi1/0/24` que baja al Piso 2.
3. **Evidencia que lo confirma:**
   - En `SW-CORE`, el puerto `Gi1/0/24` figura en estado **`err-disabled (bpduguard)`**.
   - Revisando el log (`show logging`), a las 08:58 AM el puerto recibió una trama BPDU desde abajo y se apagó automáticamente para proteger la red. ¿Qué pasó? Alguien en el Piso 2 conectó un cable de red entre dos bocas de pared pensando que estaba suelto, armando un bucle en un switch no gestionable de escritorio.
4. **Resolución arquitectónica:**
   - Identificamos y desconectamos el bucle físico en el Piso 2, reactivamos la interfaz en el core (`shutdown` / `no shutdown`), verificamos que los errores y el consumo de CPU estén en baseline, y activamos *Loop Protection / BPDU Guard* en los puertos de acceso de `SW-PISO2` para que la próxima vez se bloquee solo la boca del escritorio afectado y no todo el enlace troncal del piso.

---

## 🧠 Modelo mental

Pensá en esto como **diagnosticar por qué no sale agua de la canilla del baño en el segundo piso de un edificio**.

Un principiante desarma la canilla o llama a la empresa de agua de la ciudad sin mirar nada más. Un ingeniero primero mira si hay agua en la planta baja (*Divide & Conquer*). Si abajo hay agua, sabe que el suministro externo (WAN/ISP) funciona. Luego revisa la llave de paso de la cañería que sube al segundo piso (Capa 1/2 — puerto Trunk), la presión en el caño (Capa 3 — Routing/MTU) y recién al final el filtro de la canilla específica (Capa 4/7 — Firewall/Aplicación).

Y antes de cerrar una llave maestra a distancia, siempre deja un resorte de seguridad (*Safe Mode*) que vuelve a abrir la llave sola si él se queda encerrado.

---

## 🔗 Ver también

- [`osi-and-tcp-ip-models`](osi-and-tcp-ip-models.md) — El mapa detallado de las 7 capas, cabeceras y encapsulamiento
- [`physical-layer-cables-fiber-poe`](physical-layer-cables-fiber-poe.md) — Capa 1: diagnóstico físico de cobre, fibra óptica y PoE
- [`netops-day-to-day-maintenance-and-observability`](netops-day-to-day-maintenance-and-observability.md) — Mantenimiento preventivo, backups y monitoreo
