⬅️ [Volver a Conceptos](README.md)

# Operación y Mantenimiento del Día a Día (NetOps) — Observabilidad, backups en Git y ventanas sin corte

**Capa OSI principal:** Capas 1 a 7 (Operación Integral) | **Estándares:** `RFC 3411 (SNMPv3)`, `RFC 5424 (Syslog)`, `RFC 7011 (IPFIX/NetFlow)`, `IEEE 802.1AB (LLDP)`

---

## 🧠 ¿Qué es?

Diseñar y configurar una red desde cero es solo el **10% del trabajo** de un ingeniero de redes; el **90% restante** es **mantenerla viva, rápida, segura y documentada durante años** mientras se agregan usuarios, se cortan fibras en la calle, salen vulnerabilidades de firmware y se queman fuentes de alimentación.

La disciplina de **NetOps (Operación de Redes)** transforma la administración artesanal ("entrar a mirar router por router cuando alguien llama quejándose") en un sistema de ingeniería proactivo sostenido por tres pilares:

1. **Observabilidad continua (`SNMP + Syslog + NetFlow`):** Enterarte de que un enlace óptico se está degradando o que una fuente redundante murió **antes** de que se caiga el servicio.
2. **Gestión de Configuración como Código (`Backups en texto plano + Git`):** Tener el historial automático de cada cambio hecho en cada switch y router para poder auditar un `diff` o reconstruir un equipo quemado en 10 minutos.
3. **Ventanas de Mantenimiento Estandarizadas:** Actualizar firmwares y reemplazar equipos críticos con protocolos de pre-check, salvavidas y rollback probado.

---

## 🎯 ¿Por qué importa en el día a día?

La diferencia entre un administrador que vive estresado recibiendo llamados los domingos y un ingeniero NetOps tranquilo está en estos hábitos operativos:

- **En diseño:** Si desde el día 1 nombrás cada interfaz (`description` / `comment`) y activás **LLDP**, la red se autodocumenta sola.
- **En operación/mantenimiento:** Si se quema un router MikroTik un martes a la mañana y solo tenías un archivo `.backup` binario (o ningún backup), al comprar un modelo nuevo más moderno **el `.backup` binario no te sirve o te clona las direcciones MAC viejas causando un desastre**. Si tenías el `.rsc` en texto plano en Git, lo adaptás y levantás la empresa en 15 minutos.
- **En troubleshooting:** Si un router se reinicia solo a las 03:00 AM, **la memoria RAM local del equipo se vacía al reiniciar**: sin un servidor **Syslog externo**, jamás sabrás si se reinició por un corte de energía, por un ataque, por falta de RAM o por el *Watchdog*.

---

## ⚙️ Cómo funciona por dentro

### 1. Las 3 Columnas de la Observabilidad de Red

Ningún protocolo de monitoreo lo ve todo. Una red profesional combina tres lentes complementarios:

```text
+-----------------------------------------------------------------------------------+
|                      CENTRO DE OBSERVABILIDAD NETOPS                              |
+-------------------------+-----------------------------+---------------------------+
| 1. SNMP (UDP 161 / 162) | 2. SYSLOG (UDP/TCP 514)     | 3. NETFLOW / IPFIX (2055) |
| "¿CÓMO ESTÁ la salud?"  | "¿QUÉ EVENTO ocurrió?"      | "¿QUIÉN gasta el ancho?"  |
+-------------------------+-----------------------------+---------------------------+
| - Mbps por cada puerto  | - Login SSH exitoso/fallido | - IP Origen -> IP Destino |
| - Errores CRC / Drops   | - Puerto Gi1/0/5 pasó a DOWN| - Puerto TCP/UDP y Bytes  |
| - CPU, RAM, Temp (°C)   | - OSPF vecino cayó por Dead | - "La PC 10.1.10.84 está  |
| - Potencia SFP (-5 dBm) | - Puerto bloqueado BPDUguard|    bajando 850 Mbps desde |
| - Watts PoE consumidos  | - Sobrevive a un reinicio!  |    Steam/Windows Update"  |
+-------------------------+-----------------------------+---------------------------+
  (LibreNMS / Prometheus / Zabbix)   (Graylog / Loki / rsyslog)    (Akvorado / Elastiflow / ntopng)
```

### Anatomía / Componentes clave del mantenimiento diario

| Herramienta / Práctica | Protocolo / Formato | Función real en el día a día | Qué pasa si falta |
|------------------------|---------------------|------------------------------|-------------------|
| **LLDP (`802.1AB`) / CDP / MNDP** | Capa 2 Multicast local | Cada switch y AP le dice a su vecino directo por cada cable: *"Soy `SW-PISO2`, IP `10.1.99.12`, y me estás tocando en mi puerto `Gi1/0/24`"* | Si nadie etiquetó los cables del rack, sin LLDP no tenés idea de a dónde va cada cable sin desconectarlo |
| **Backup en Texto Plano (`.rsc` / `running-config`)** | Script CLI legible en ASCII | Contiene los comandos exactos que recrean la configuración. Se guarda en **Git** (automáticamente con **Oxidized** o script SSH nocturno) | Sin backup en texto plano, no podés comparar qué cambió entre ayer y hoy (`git diff`) ni migrar la configuración a un modelo de hardware diferente |
| **Backup Binario (`.backup` en MikroTik)** | Archivo binario cifrado | Guarda absolutamente todo (incluyendo certificados, claves SSH del host y direcciones MAC) para restaurar **exclusivamente en el mismo equipo o modelo idéntico** | Si restaurás un `.backup` binario de un router en otro router de la misma red, **clonás sus direcciones MAC** y rompés toda la Capa 2 |
| **Doble actualización en MikroTik (`RouterOS` + `RouterBOOT`)** | `/system package` + `/system routerboard` | En MikroTik hay **dos** firmwares: el Sistema Operativo (`RouterOS`) y el Bootloader de placa (`RouterBOOT`, equivalente a la BIOS) | Muchos técnicos actualizan solo `RouterOS` y dejan el `RouterBOOT` con la versión de hace 4 años (`current-firmware != upgrade-firmware`), sufriendo bugs de arranque o puertos SFP |

---

### 2. Anatomía de una Ventana de Mantenimiento Profesional (Sin Incendios)

Nunca se actualiza un router o se reemplaza un switch "sobre la marcha". Todo cambio programado sigue este protocolo de **4 fases**:

```text
FASE 1: PRE-CHECK (T - 15 min)               FASE 2: BACKUP DOBLE (T - 5 min)
- Guardar foto del estado sano actual:       - Exportar texto plano (.rsc / running-config)
  * Cantidad de rutas activas y vecinos OSPF - Exportar binario (.backup) y copiarlos
  * Estado de túneles VPN y puertos Trunk      FUERA del equipo (a tu laptop / Git)
  * Tabla ARP y tráfico baseline
                  |
                  v
FASE 3: EJECUCIÓN CON SALVAVIDAS (T = 0)     FASE 4: POST-CHECK Y CIERRE (T + 10 min)
- Activar Safe Mode (Ctrl+X) o reload in 10  - Comparar contra la foto de la Fase 1:
- Aplicar el cambio (o subir firmware +        * ¿Levantaron todos los vecinos OSPF y VPNs?
  /system routerboard upgrade + reboot)        * ¿Hay 0 errores CRC nuevos en los puertos?
- Tener acceso Out-of-Band (4G / Consola)    - Desactivar Safe Mode / write memory
```

---

### 3. Checklist de Mantenimiento Preventivo (Qué revisar antes de que algo falle)

| Frecuencia | Qué revisar ( toma 10 minutos con monitoreo o CLI) | Qué anomalía estás buscando |
|------------|----------------------------------------------------|-----------------------------|
| **Diario / Automático (Alertas)** | Estado de enlaces WAN Dual-WAN, túneles VPN Site-to-Site, vecinos OSPF/BGP y alertas de login fallido | Un ISP secundario de backup que se cayó hace 3 días en silencio: si no lo arreglás hoy, te vas a enterar el día que se corte el ISP principal |
| **Semanal** | Contadores de errores físicos (`CRC / FCS / Drops`) en switches troncales y potencia óptica SFP (`Rx Power dBm`) | Un puerto con `CRC` subiendo de a poco o una fibra cuya potencia cayó de `-8 dBm` a `-22 dBm` por humedad en una caja exterior |
| **Mensual** | Auditoría de backups en Git/Oxidized, verificación de que `running-config == startup-config`, consumo de presupuesto PoE y espacio en disco/flash | Cambios temporales hechos en una guardia que en Cisco/Aruba nunca fueron guardados con `write memory` (se perderán en el próximo corte de luz) |
| **Trimestral** | Ventana de actualización a versión **Stable / Long-Term** de firmware, limpieza de reglas de firewall vencidas (`comment="Temporal..."`) y prueba real de failover (apagar WAN 1 / Router Master VRRP) | Vulnerabilidades CVE en servicios expuestos y baterías de UPS agotadas que ya no aguantan ni 30 segundos de corte eléctrico |

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Operación NetOps del Día a Día | Cisco IOS / Catalyst | MikroTik RouterOS v7 | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `systemd`) |
|--------------------------------|----------------------|----------------------|----------------------------|--------------------------------|
| **Documentar para qué sirve un puerto/regla** | `description UPLINK_SW_PISO2` | `comment="UPLINK_SW_PISO2"` | `name "UPLINK_SW_PISO2"` | `ip link set eth0 alias "UPLINK_SW_PISO2"` |
| **Descubrir qué equipo está en cada boca** | `show cdp neighbors detail` / `show lldp neighbors` | `/ip neighbor print detail` | `show lldp info remote-device` | `lldpcli show neighbors` |
| **Exportar configuración en texto plano (Git)** | `show running-config` / `archive` | `/export show-sensitive file=cfg-hoy` | `show running-config` | Archivos `/etc/netplan/`, `/etc/frr/frr.conf` |
| **Verificar versión de Bootloader / Firmware de placa** | `show version` (`ROM: System Bootstrap`) | `/system routerboard print` (`current-firmware` vs `upgrade-firmware`) | `show flash` / `show boot-history` | `fwupdmgr get-devices` / `dmidecode` |
| **Enviar logs a un servidor Syslog central (`10.1.40.50`)** | `logging host 10.1.40.50` + `service timestamps log datetime msec` | `/system logging action add name=remoto target=remote remote=10.1.40.50` | `logging 10.1.40.50` | `rsyslog` / `systemd-journal-remote` |
| **Activar monitoreo SNMPv2c / SNMPv3** | `snmp-server community ... RO <ACL>` / `snmp-server group ... v3 priv` | `/snmp set enabled=yes` + `/snmp community` | `snmp-server community ...` | `snmpd` / `prometheus-node-exporter` |
| **Exportar flujos de tráfico (NetFlow / IPFIX)** | `ip flow-export destination 10.1.40.50 2055` | `/ip traffic-flow set enabled=yes` + `target` | `sflow 1 destination 10.1.40.50` | `softflowd` / `ipt-netflow` |

---

## 📊 Señales normales vs anómalas (Diagnóstico Operativo)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Salida de `/system routerboard print` en MikroTik** | `current-firmware: 7.16.1` coincide con `upgrade-firmware: 7.16.1` | `current-firmware: 6.48.6` mientras `upgrade-firmware: 7.16.1` | Se actualizó el sistema operativo RouterOS, pero nunca se ejecutó `/system routerboard upgrade` + segundo `reboot` |
| **Razón del último reinicio (`show version` / `/system health` / log)** | `System returned to ROM by reload` (reinicio programado en ventana) | `router was rebooted without proper shutdown, probably power outage` o `watchdog timer expired` | **Corte eléctrico (UPS agotada), fuente de alimentación fallando o cuelgue de kernel** en que actuó el Watchdog |
| **Diferencia en Git/Oxidized respecto al día anterior (`git diff`)** | `0` líneas cambiadas (o el cambio documentado en el ticket del día) | Aparecen reglas de NAT nuevas, usuarios nuevos o puertos movidos de VLAN sin ticket | **Config Drift (Deriva de configuración):** cambios manuales sin documentar o compromiso de seguridad |
| **Espacio libre en almacenamiento Flash del router/switch** | `> 30%` libre | `0 KB` libres (`disk is full`) | Se acumularon decenas de archivos `.backup`, capturas `.pcap` de packet sniffer o imágenes `.npk`/`.bin` viejas; si el disco llega a `0 KB`, el router **no puede guardar cambios nuevos de configuración** |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Guardar los backups de configuración únicamente adentro de la memoria interna (`Files`) del propio router:** Si al router le cae una sobretensión eléctrica por la línea del proveedor o se quema su memoria NAND flash, **perdés el router y perdés todos los backups que estaban guardados adentro de él**. Un backup solo existe cuando ya fue copiado **fuera** del equipo (a tu repositorio Git, servidor de backups o estación de administración).
- **❌ Dejar activado LLDP / CDP / MNDP en las interfaces públicas WAN que miran hacia el proveedor de Internet:** Esos protocolos de descubrimiento son maravillosos hacia tus switches internos (`LAN / Management`), pero si los dejás abiertos hacia la calle (`WAN`), le estás regalando a terceros el modelo exacto de tu router, la versión exacta de tu sistema operativo, el nombre de la empresa y las IPs internas configuradas. En MikroTik, limitá siempre `/ip neighbor discovery-settings set discover-interface-list=LAN` (o `MGMT`).
- **❌ Actualizar el firmware de un router remoto un viernes a las 18:00 hs o saltar 3 versiones mayores de golpe sin leer el *Changelog*:** Las actualizaciones de firmware se hacen en ventana controlada, con los archivos `.rsc` y `.backup` ya descargados, leyendo las notas de la versión (por ejemplo, cambios de sintaxis entre RouterOS v6 y v7, o cambios en BGP/OSPF/WiFiWave2) y teniendo un contacto físico en el sitio por si hay que conectar un cable de consola.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

Un domingo de tormenta eléctrica se quema la placa de un router MikroTik `RB3011` que administraba 8 VLANs, 15 túneles VPN, colas QoS y reglas de firewall de una empresa distribuidora. En el depósito de repuestos de IT no hay otro `RB3011` igual, pero sí tienen un **`RB5009` nuevo** (que tiene otra arquitectura de procesador, otro chip de switch y otra disposición de puertos: tiene un puerto 2.5G `ether1`, 7 puertos Gigabit y un SFP+).

El administrador anterior solo había guardado un archivo binario **`empresa.backup`** del `RB3011`.

### Análisis paso a paso por capas

1. **Qué pasa cuando intentan restaurar el `.backup` binario del `RB3011` dentro del `RB5009`:**
   - Como el archivo `.backup` binario es un volcado crudo de la base de datos interna pensado para el mismo modelo de hardware, al cargarlo en un modelo diferente con otro chip y distinta numeración de interfaces, **las interfaces quedan descalzadas (`*F` / puertos fantasma), se clonan MACs que no corresponden al hardware nuevo y el bridge pierde acceso**.
2. **Por qué el enfoque NetOps con `.rsc` en texto plano salva el día:**
   - Por suerte, el sistema de backups automatizado por SSH (`Oxidized`) había guardado todas las noches la salida de **`/export show-sensitive`** (`empresa.rsc`) en un repositorio privado de Git.
3. **Resolución paso a paso en 15 minutos:**
   - Abrimos `empresa.rsc` en cualquier editor de texto (VS Code / Vim).
   - Como es **texto plano legible**, vemos claramente cada bloque:
     - `/interface vlan`, `/ip pool`, `/ip dhcp-server`, `/ip address`, `/ip firewall filter`, `/ip firewall nat`, `/interface wireguard` y `/ip route`.
   - Adaptamos en 2 minutos los nombres de los puertos físicos que cambiaron entre el `RB3011` (`ether1..ether10` en dos chips) y el `RB5009` (`ether1..ether8` + `sfp-sfpplus1` en un único chip Marvell con Hardware Offload total) sin arrastrar ninguna dirección MAC vieja (`admin-mac`).
   - Pegamos los bloques por consola en el `RB5009` limpio (o importamos `/import file-name=rb5009-limpio.rsc`).
   - En **15 minutos exactos**, las 8 VLANs, los 15 túneles WireGuard y todas las políticas de firewall están funcionando en el hardware nuevo sin haber perdido ni una sola regla.

---

## 🧠 Modelo mental

Pensá en esto como **el mantenimiento y la bitácora de vuelo de un avión comercial**:

- **Las 3 patas de la Observabilidad** son la cabina del avión: **SNMP** es el tablero de instrumentos en vivo (altímetro, presión de aceite, combustible y temperatura de los motores), **NetFlow** es el manifiesto de carga que te dice cuánto pesa cada pasajero y cada valija, y **Syslog externo** es la **Caja Negra indestructible** que transmite todo a la torre de control para que, incluso si se apaga la cabina, quede registrado segundo a segundo qué pasó antes del incidente.
- **Un backup binario (`.backup`)** es sacarle un molde de yeso al motor específico de ese avión: solo encaja si comprás exactamente el mismo motor del mismo año. **Un backup en texto plano (`.rsc` / `running-config` en Git)** son **los planos de ingeniería firmados**: con los planos en la mano, podés entender qué modificó el mecánico ayer (`git diff`) y podés construir o configurar un avión más moderno en minutos.

---

## 🔗 Ver también

- [`how-to-think-like-network-engineer`](how-to-think-like-network-engineer.md) — El punto de partida: los 3 planos (Datos, Control y Gestión), metodologías de diagnóstico y uso de Safe Mode / reload in
- [`osi-and-tcp-ip-models`](osi-and-tcp-ip-models.md) — El mapa completo de las 7 capas que acabás de recorrer de punta a punta
- [`multivendor-cli-rosetta-stone`](../reference/multivendor-cli-rosetta-stone.md) — Tu tabla de consulta rápida diaria con todos los comandos equivalentes entre Cisco, MikroTik, Aruba y Linux
