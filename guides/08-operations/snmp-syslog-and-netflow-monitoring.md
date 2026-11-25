⬅️ [Volver a Guías](../README.md)

# Monitoreo con SNMP, Syslog Centralizado y NetFlow / Traffic Flow — Guía práctica multi-vendor

**Dominio:** `08-operations`
**Nivel:** 🟡 Intermedio
**Estándares:** `RFC 3411 (SNMPv3)`, `RFC 1213 (MIB-II)`, `RFC 5424 (Syslog)`, `RFC 7011 (IPFIX / NetFlow v9)`
**Concepto base:** [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Desde el Servidor Linux de Monitoreo: Probar consulta SNMPv2c / SNMPv3 hacia un switch o router
snmpwalk -v2c -c MonitoreoRO_2026 10.1.99.1 1.3.6.1.2.1.1
snmpwalk -v3 -l authPriv -u netops-snmp -a SHA -A "AuthPass!2026" -x AES -X "PrivPass!2026" 10.1.99.1 1.3.6.1.2.1.1

# MikroTik RouterOS v7: Verificar estado de SNMP, reglas de Syslog remoto y exportación Traffic Flow
/snmp print
/system logging print
/ip traffic-flow print

# Cisco IOS: Verificar estado de SNMP, servidor Syslog y exportación NetFlow
show snmp
show logging
show ip flow export
```

---

## 📑 Índice

1. [¿Qué resuelve y cuándo usarlo?](#1--qué-resuelve-y-cuándo-usarlo)
2. [Topología de referencia](#2-️-topología-de-referencia)
3. [Configuración paso a paso por fabricante](#3-️-configuración-paso-a-paso-por-fabricante)
4. [Salida clave e interpretación de flags](#4--salida-clave-e-interpretación-de-flags)
5. [Uso en troubleshooting](#5--uso-en-troubleshooting)
6. [Mantenimiento, backup y rollback seguro](#6-️-mantenimiento-backup-y-rollback-seguro)
7. [Errores comunes en producción](#7-️-errores-comunes-en-producción)
8. [Buenas prácticas profesionales](#8--buenas-prácticas-profesionales)
9. [Referencias internas](#9--referencias-internas)

---

## 1. 🧠 ¿Qué resuelve y cuándo usarlo?

Si te enterás de que se cortó el enlace de Internet secundario o de que un disco/SFP está fallando porque un usuario te llama por teléfono, **tu red está operando a ciegas**.

En esta guía configuramos las **3 columnas de la observabilidad de red** apuntando hacia un servidor central de monitoreo (`10.1.99.10`):

1. **SNMP (`UDP 161`):** Para que **LibreNMS, Zabbix o Prometheus (`snmp_exporter`)** grafique cada 1 a 5 minutos el tráfico por interfaz, errores CRC, CPU, temperatura, consumo PoE y potencia óptica en `dBm`.
2. **Syslog Remoto (`UDP/TCP 514`):** Para que cada login, caída de puerto, bloqueo de `bpduguard` o cambio de configuración se guarde fuera del router y **sobreviva aunque el router se reinicie o se apague**.
3. **NetFlow v9 / IPFIX (`UDP 2055`):** Para responder en 5 segundos la pregunta del millón cuando se satura Internet: **"¿Qué IP interna exacta se está comiendo los `500 Mbps` de la empresa y contra qué servidor de Internet?"**.

> **🧠 Recordatorio del modelo mental:** Pensá en estas tres herramientas como **la cabina de un avión**: **SNMP** son las agujas del tablero (velocidad, temperatura, combustible), **Syslog externo** es la Caja Negra enviada a la torre de control y **NetFlow** es la balanza que te dice cuánto pesa la valija de cada pasajero individual.

---

## 2. 🗺️ Topología de referencia

Todos los equipos de red envían su telemetría hacia el Servidor de Observabilidad (`10.1.99.10`) dentro de la `VLAN 99 Management`:

```text
+-----------------+   1. SNMP Poll (UDP 161)    +----------------------------------------+
|   RTR-BORDE     | <-------------------------- | Servidor de Observabilidad (Linux)     |
|  (10.1.99.1)    |   2. Syslog (UDP 514)       | IP: 10.1.99.10                         |
|                 | --------------------------> | - LibreNMS / Prometheus + Grafana      |
|   SW-CORE       |   3. NetFlow/IPFIX (2055)   | - rsyslog / Loki / Graylog             |
|  (10.1.99.2)    | --------------------------> | - Akvorado / ntopng / Elastiflow       |
+-----------------+                             +----------------------------------------+
```

| Servicio | Puerto y Protocolo | Quién inicia la conexión | Frecuencia / Volumen |
|----------|:------------------:|--------------------------|----------------------|
| **SNMP Polling** | `UDP 161` | El **Servidor (`10.1.99.10`)** consulta al Router/Switch | Cada `60s` o `300s` (muy liviano) |
| **Syslog** | `UDP 514` (o `TCP 514`) | El **Router/Switch** envía al Servidor | En tiempo real al ocurrir cada evento |
| **NetFlow v9 / IPFIX** | `UDP 2055` (o `4739`) | El **Router** envía resúmenes de flujos al Servidor | Continuo (resumen de cabeceras L3/L4, no copia el payload) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Regla de seguridad crítica:**
>
> 1. Jamás uses la comunidad SNMP por defecto **`public`** ni habilites permisos de escritura (`RW / write`).
> 2. Restringí siempre SNMP para que **solo responda a la IP exacta del servidor de monitoreo (`10.1.99.10/32`)** y preferí **SNMPv3 (`authPriv` con SHA + AES)** siempre que el equipo lo soporte.

### A. MikroTik RouterOS (v7+)

```text
# 1. CONFIGURAR SNMPv3 (Cifrado y autenticado — Recomendado) o SNMPv2c restringido por IP:
/snmp community set [find default=yes] disabled=yes
/snmp community add \
    name=netops-v3 \
    addresses=10.1.99.10/32 \
    security=private \
    authentication-protocol=SHA1 \
    encryption-protocol=AES \
    authentication-password="AuthPassFuerte!2026" \
    encryption-password="PrivPassFuerte!2026" \
    read-access=yes \
    write-access=no
/snmp set enabled=yes contact="netops@empresa.local" location="Rack-Central-Sede1"

# 2. CONFIGURAR SYSLOG REMOTO HACIA 10.1.99.10 (UDP 514):
/system logging action add \
    name=syslog-central \
    target=remote \
    remote=10.1.99.10 \
    remote-port=514 \
    src-address=10.1.99.1 \
    bsd-syslog=yes
/system logging add topics=info,!SNMP action=syslog-central
/system logging add topics=warning action=syslog-central
/system logging add topics=error action=syslog-central
/system logging add topics=critical action=syslog-central

# 3. CONFIGURAR TRAFFIC FLOW (NetFlow v9 / IPFIX hacia 10.1.99.10:2055):
/ip traffic-flow set enabled=yes interfaces=ether1-wan cache-entries=64k
/ip traffic-flow target add dst-address=10.1.99.10 port=2055 version=ipfix
```

### B. Cisco IOS / Catalyst

```cisco
configure terminal

! 1. ACL que solo permite consultas SNMP desde el servidor de monitoreo 10.1.99.10
ip access-list standard ACL-SNMP-ONLY
 permit 10.1.99.10
 deny   any log
exit

! 2. Configurar SNMPv3 con autenticación SHA y cifrado AES-128 (Solo Lectura)
snmp-server view VIEW-RO iso included
snmp-server group GRP-NETOPS v3 priv read VIEW-RO access ACL-SNMP-ONLY
snmp-server user netops-snmp GRP-NETOPS v3 auth sha AuthPassFuerte!2026 priv aes 128 PrivPassFuerte!2026
snmp-server location Rack-Central-Sede1
snmp-server contact netops@empresa.local

! 3. Configurar Syslog Remoto con marcas de tiempo en milisegundos y zona horaria
service timestamps log datetime msec localtime show-timezone
logging source-interface Vlan99
logging host 10.1.99.10
logging trap informational

! 4. (En Routers Cisco IOS-XE) Configurar Flexible NetFlow hacia 10.1.99.10:2055
flow exporter EXP-NETOPS
 destination 10.1.99.10
 source Vlan99
 transport udp 2055
 export-protocol netflow-v9
exit
flow monitor MON-WAN
 exporter EXP-NETOPS
 record netflow ipv4 original-input
exit
interface GigabitEthernet0/0
 ip flow monitor MON-WAN input
 ip flow monitor MON-WAN output
exit

end
write memory
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link)

```text
# En Aruba ProCurve / AOS-S:
configure
# 1. SNMPv3 y restricción al servidor 10.1.99.10
snmpv3 enable
snmpv3 user "netops-snmp" auth sha "AuthPassFuerte!2026" priv aes "PrivPassFuerte!2026"
snmpv3 group managerpriv user "netops-snmp" sec-model ver3
no snmp-server community "public"
# 2. Syslog centralizado
logging 10.1.99.10
logging facility local7
logging severity info
# 3. sFlow para muestreo de tráfico en puertos troncales
sflow 1 destination 10.1.99.10 6343
sflow 1 polling 1-24 20
sflow 1 sampling 1-24 512
write memory
```

### D. Servidor Linux de Observabilidad (`rsyslog` receptor + pruebas `snmpwalk`)

```bash
# 1. Instalar cliente SNMP y MIBs estándar en el servidor Linux para probar consultas
sudo apt install -y snmp snmp-mibs-downloader

# 2. Habilitar rsyslog para recibir logs por red (UDP 514) separando un archivo por cada IP de router/switch
cat << 'EOF' | sudo tee /etc/rsyslog.d/10-network-devices.conf
module(load="imudp")
input(type="imudp" port="514")

$template NetworkLogs,"/var/log/netops/%FROMHOST-IP%/%$YEAR%-%$MONTH%-%$DAY%.log"
if ($fromhost-ip != '127.0.0.1') then ?NetworkLogs
& stop
EOF

sudo systemctl restart rsyslog
```

---

## 4. 🔑 Salida clave e interpretación de flags

### Prueba de `snmpwalk` desde Linux y OIDs más importantes

```text
$ snmpwalk -v3 -l authPriv -u netops-snmp -a SHA -A "AuthPassFuerte!2026" -x AES -X "PrivPassFuerte!2026" 10.1.99.1 1.3.6.1.2.1.1
iso.3.6.1.2.1.1.1.0 = STRING: "RouterOS RB5009UG+S+"
iso.3.6.1.2.1.1.3.0 = Timeticks: (124502100) 14 days, 9:50:21.00
iso.3.6.1.2.1.1.5.0 = STRING: "RTR-BORDE"
```

### Tabla de OIDs SNMP Universales que todo ingeniero debe conocer

| OID / Rama MIB | Nombre Estándar | Qué devuelve exactamente | Por qué es crítico monitorearlo |
|----------------|-----------------|--------------------------|---------------------------------|
| **`1.3.6.1.2.1.1.3.0`** | `sysUpTime` | Tiempo encendido desde el último arranque | Si cae a `0`, el equipo se reinició (corte eléctrico o crash) |
| **`1.3.6.1.2.1.31.1.1.1.1`** | `ifName` (`IF-MIB`) | Nombres de todas las interfaces (`Gi1/0/1`, `ether1`) | Base para mapear gráficos de tráfico por puerto |
| **`1.3.6.1.2.1.31.1.1.1.6 / .10`** | `ifHCInOctets` / `ifHCOutOctets` | Contador de **64 bits** de bytes recibidos y transmitidos | ⚠️ **Usar siempre los contadores `HC` de 64 bits:** los viejos de 32 bits (`ifInOctets`) dan la vuelta a cero cada 34 segundos en un puerto de 1 Gbps! |
| **`1.3.6.1.2.1.2.2.1.14 / .20`** | `ifInErrors` / `ifOutErrors` | Errores físicos de recepción (CRC/FCS) y transmisión | Cualquier valor `> 0` creciendo alerta de un cable UTP o fibra deteriorándose |
| **`1.3.6.1.2.1.105.1.3.1`** | `pethMainPsePower` (`POWER-ETHERNET-MIB`) | Presupuesto total en Watts y consumo actual PoE | Alerta preventiva cuando el switch supera el `80%` de su fuente PoE |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: El enlace a Internet está al 100% y aún no tenés un colector NetFlow instalado: ¿cómo ver en 5 segundos quién consume el ancho de banda en MikroTik?

1. **Verificación rápida nativa en MikroTik (`Torch`):**
   - Ejecutá en consola: **`/tool torch interface=ether1-wan src-address=0.0.0.0/0 dst-address=0.0.0.0/0 port=any ip-protocol=any`** (o en una VLAN interna: `/tool torch interface=vlan10 src-address=10.1.10.0/24`).
2. **Qué muestra en pantalla:** Una tabla en vivo ordenada por `TX` y `RX` (en `Mbps`) con la IP interna exacta, la IP externa y el puerto que está saturando el enlace en este mismo segundo.

### Síntoma 2: Tus gráficos de LibreNMS/Zabbix de un puerto de `1 Gbps` o `10 Gbps` se ven "serruchados" o marcan a lo sumo `114 Mbps` cuando en realidad pasan `900 Mbps`

1. **Causa raíz:** Estás consultando por SNMPv1 o usando los contadores antiguos de **32 bits (`ifInOctets`)**. Un entero de 32 bits llega a su tope máximo (`4.294.967.295 bytes` = `4 GB`) en solo **34 segundos** a `1 Gbps` (y en **3,4 segundos** a `10 Gbps`), volviendo a cero antes de que tu servidor haga el siguiente poll de 1 minuto.
2. **Corrección:** Asegurate de usar **SNMPv2c o SNMPv3** y los contadores de **64 bits (`ifHCInOctets` / `ifXTable`)**.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cuidado con la rotación de disco en el Servidor Syslog / NetFlow:**
  - Un router de borde con una regla de firewall que tiene `log=yes` sobre los `DROP` de la WAN puede escupir **50.000 líneas de log por minuto** durante un escaneo de puertos de Internet, llenando el disco de tu servidor Linux en una tarde.
  - **Regla profesional:** No pongas `log=yes` en la regla final de `drop` de la WAN en producción (solo encendé el log en esa regla durante 2 minutos cuando estés diagnosticando algo y volvelo a apagar), y configurá siempre `logrotate` en `/etc/logrotate.d/` del servidor Linux para comprimir y borrar logs mayores a 30/90 días.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Dejar la comunidad SNMP `public` habilitada y sin filtro de IP (`0.0.0.0/0`):** Cualquiera en la red (o desde Internet si olvidaste cerrar `UDP 161` en `INPUT`) puede hacer un `snmpwalk` y descargar la tabla ARP completa, la tabla de rutas, todas las VLANs, las IPs internas y los nombres de todos tus equipos en 3 segundos.
- **❌ En MikroTik, olvidar excluir `!snmp` en la regla de Syslog `topics=info`:** Si agregás una regla de logging con `topics=info` sin poner **`topics=info,!snmp`**, cada vez que LibreNMS o Zabbix consulte los 200 OIDs del router cada 1 minuto, el router generará 200 líneas de log diciendo *"SNMP query from 10.1.99.10"*, inundando tu servidor Syslog con basura inútil.
- **❌ No configurar `logging source-interface` / `src-address` hacia la IP de Management (`10.1.99.1`):** Si un router tiene 10 VLANs y no fijás la IP de origen de sus paquetes Syslog/NetFlow, el servidor recibirá logs desde distintas IPs del mismo router si cambia una ruta, duplicando el equipo en el dashboard.

---

## 8. ✅ Buenas prácticas profesionales

- **Sincronizar NTP en todos los equipos antes de activar Syslog:** Un servidor Syslog donde el Switch 1 tiene las `14:00 hs`, el Switch 2 tiene las `11:00 hs` (UTC sin zona horaria) y el Router tiene fecha `1970` no sirve para reconstruir la cronología de ningún incidente.
- **Alertar sobre tendencias, no solo sobre caídas totales:** Configurar alertas tempranas cuando la potencia óptica de un SFP baje de `-20 dBm`, cuando la temperatura de un switch supere los `65 °C` o cuando un puerto sume más de `50 errores CRC` en una hora.

---

## 9. 🔗 Referencias internas

- [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md) — El modelo mental de las 3 columnas de observabilidad y checklist preventivo
- [`network-ports-protocols-and-multicast`](../../reference/network-ports-protocols-and-multicast.md) — Referencia rápida de puertos `UDP 161/162` (SNMP), `514/6514` (Syslog) y `2055/4739/6343` (NetFlow/IPFIX/sFlow)
- [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md) — Por qué NTP (`UDP 123`) es requisito previo indispensable para el servidor Syslog
