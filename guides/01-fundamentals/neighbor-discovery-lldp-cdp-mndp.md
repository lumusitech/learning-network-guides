⬅️ [Volver a Guías](../README.md)

# Descubrimiento de Vecinos (LLDP, CDP y MNDP) — Cómo mapear una red sin documentación

**Dominio:** `01-fundamentals`
**Nivel:** 🟢 Básico
**Estándares:** `IEEE 802.1AB (LLDP)`, `ANSI/TIA-1057 (LLDP-MED)`, `Cisco CDP`, `MikroTik MNDP`
**Concepto base:** [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver switches, routers y APs vecinos tanto por CDP (Cisco) como por LLDP (Universal)
show cdp neighbors
show cdp neighbors detail
show lldp neighbors
show lldp neighbors detail

# MikroTik RouterOS v7: Ver todos los vecinos descubiertos (habla LLDP + CDP + MNDP a la vez)
/ip neighbor print
/ip neighbor print detail

# Aruba / HP ProCurve: Ver dispositivos conectados en cada boca por LLDP y CDP
show lldp info remote-device
show cdp neighbors

# Linux (con demonio lldpd instalado): Ver a qué switch, puerto y VLAN está conectada esta máquina
lldpcli show neighbors
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

Cuando llegás por primera vez a una empresa sin planos de red (o donde el rack es una maraña de cables sin etiquetas), la peor forma de averiguar a dónde va cada cable es desenchufarlo a ver quién grita.

Los protocolos de **Descubrimiento de Vecinos de Capa 2** —el estándar universal **LLDP (`IEEE 802.1AB`)**, el propietario **Cisco CDP** y el **MikroTik MNDP**— hacen que cada router, switch, teléfono IP, punto de acceso WiFi y servidor Linux envíe periódicamente por cada uno de sus puertos físicos una tarjeta de presentación diciendo: **"¡Hola! Soy el equipo `SW-PISO2`, modelo `CRS326`, mi IP de gestión es `10.1.99.12` y este cable está enchufado en mi puerto `ether24`"**.

> **🧠 Recordatorio del modelo mental:** Pensá en LLDP/CDP como **tarjetas personales que se pasan por debajo de la puerta entre habitaciones contiguas**: nunca cruzan un switch hacia otro salto (no se reenvían), por lo que si ves a un vecino en tu puerto 5, tenés la **certeza física absoluta** de que la otra punta de ese cable del puerto 5 está enchufada directamente en ese equipo.

---

## 2. 🗺️ Topología de referencia

Con un solo comando en `SW-CORE`, podemos reconstruir todo este plano físico sin tocar ni un solo cable del rack:

```text
                   [ISP Módem]
                        |  (❌ En ether1-wan APAGAMOS LLDP/CDP/MNDP por seguridad!)
                        v
            +-----------------------+
            |       RTR-BORDE       | (MikroTik RB5009 — 10.1.99.1)
            +-----------------------+
               (ether2) ||
                        ||  <--- Intercambian LLDP + CDP + MNDP
               (Gi1/0/1)||
            +-----------------------+
            |        SW-CORE        | (Cisco Catalyst — 10.1.99.2)
            +-----------------------+
        (Gi1/0/24) /         \ (Gi1/0/10)
                  /           \
       (Puerto 25)             (eth0)
  +------------------+     +------------------+
  |     SW-PISO2     |     |   AP-RECEPCION   |
  | (Aruba 2530)     |     | (Ubiquiti UniFi) |
  | IP: 10.1.99.12   |     | IP: 10.1.99.51   |
  +------------------+     +------------------+
```

| Protocolo | Estándar / Dueño | Destino en Capa 2 / 3 | Intervalo de anuncio | Quién lo entiende |
|-----------|------------------|-----------------------|:--------------------:|-------------------|
| **LLDP** | **`IEEE 802.1AB`** (Abierto) | MAC Multicast `01:80:C2:00:00:0E` (`EtherType 0x88CC`) | Cada `30 seg` (`Hold 120s`) | 🏆 **Todos:** Cisco, MikroTik, Aruba, Ubiquiti, TP-Link, Fortinet, Linux, Windows |
| **CDP** | **Cisco** (Propietario) | MAC Multicast `01:00:0C:CC:CC:CC` | Cada `60 seg` (`Hold 180s`) | Cisco, MikroTik (lo lee y envía), Aruba (lo lee) y `lldpd` en Linux |
| **MNDP** | **MikroTik** (Propietario) | Broadcast IP `255.255.255.255` (`UDP 5678`) | Cada `60 seg` | MikroTik RouterOS, SwOS y la aplicación **WinBox** (pestaña *Neighbors*) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Regla de seguridad obligatoria:** Habilitá siempre LLDP globalmente hacia tu red interna para tener visibilidad total, pero **desactivalo siempre en las interfaces WAN que dan hacia el proveedor de Internet** para no revelar modelo, versión de firmware ni IPs internas hacia afuera.

### A. Cisco IOS / Catalyst (Activar LLDP para ver equipos no-Cisco y apagar en WAN)

> *Nota:* En Cisco IOS, **CDP viene encendido de fábrica**, pero **LLDP viene apagado de fábrica**. Si conectás un MikroTik, un Aruba o un servidor Linux a un switch Cisco y no activaste `lldp run`, el Cisco no los verá con `show lldp neighbors`.

```cisco
! 1. Encender el estándar universal LLDP en todo el switch/router Cisco
configure terminal
lldp run
cdp run

! 2. En la interfaz WAN pública (si es un router de borde), apagar TANTO CDP como LLDP
interface GigabitEthernet0/0
 description WAN_ISP_FIBRA
 no cdp enable
 no lldp transmit
 no lldp receive
exit

end
write memory
```

### B. MikroTik RouterOS (v7+)

```text
# 1. Ver la configuración actual de descubrimiento de vecinos
/ip neighbor discovery-settings print

# 2. Permitir LLDP, CDP y MNDP únicamente hacia las interfaces internas (nunca hacia la WAN!)
#    (Suponiendo que tenés la lista de interfaces 'LAN' o '!WAN'):
/ip neighbor discovery-settings set \
    discover-interface-list=!WAN \
    protocol=cdp,lldp,mndp \
    lldp-med-net-policy-vlan=disabled

# 3. Ver la tabla completa de vecinos conectados en cada puerto
/ip neighbor print
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link)

```text
# En Aruba ProCurve / AOS-S (LLDP viene activo por defecto):
configure
lldp run
cdp run
# Para silenciarlo en un puerto externo no confiable (ej. puerto 24):
no lldp admin-status 24
no cdp enable 24
write memory
```

### D. Servidores Linux (`lldpd` — Para que el switch sepa qué servidor está en cada boca)

Instalar `lldpd` en tus servidores Linux y nodos Proxmox/Docker es una de las mejores prácticas de NetOps: cuando mirás el switch, el puerto te dice el hostname exacto del servidor Linux conectado ahí, y desde el servidor Linux podés ver a qué switch y boca está enchufado cada cable de red:

```bash
# 1. Instalar y habilitar el demonio LLDP (soporta LLDP, CDP, EDP y SONMP)
sudo apt install -y lldpd
sudo systemctl enable --now lldpd

# 2. Consultar desde el servidor Linux a qué switch, puerto y VLAN está conectada cada placa eth0/eno1
sudo lldpcli show neighbors
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show cdp neighbors` y `show lldp neighbors detail`)

```text
SW-CORE# show lldp neighbors
Capability codes:
    (R) Router, (B) Bridge, (T) Telephone, (W) WLAN Access Point, (S) Station
Device ID           Local Intf     Hold-time  Capability      Port ID
RTR-BORDE           Gi1/0/1        120        B,R             ether2-trunk
SW-PISO2            Gi1/0/24       120        B               25
AP-RECEPCION        Gi1/0/10       120        B,W             eth0
srv-proxmox-01      Gi1/0/5        120        S               eno1
```

### En MikroTik RouterOS (`/ip neighbor print`)

```text
[netops@RTR-BORDE] > /ip neighbor print
Columns: INTERFACE, ADDRESS, MAC-ADDRESS, IDENTITY, VERSION, BOARD
#  INTERFACE             ADDRESS      MAC-ADDRESS        IDENTITY      VERSION                              BOARD
0  ether2-trunk          10.1.99.2    00:1A:2B:3C:4D:01  SW-CORE       Cisco IOS Software, C9200L (17.9.4)  cisco C9200L-24P-4G
1  vlan99-mgmt,ether2    10.1.99.12   AA:BB:CC:11:22:33  SW-PISO2      WC.16.11.0002                        Aruba JL255A 2930F
2  vlan99-mgmt,ether2    10.1.99.51   74:83:C2:99:88:77  AP-RECEPCION  6.6.73.15402                         U6-Pro
```

### Tabla de interpretación de columnas y flags

| Columna / Campo |Dónde aparece | Qué significa realmente | Cómo se usa para armar el plano de red |
|-----------------|--------------|-------------------------|----------------------------------------|
| **`Local Intf` / `INTERFACE`** | En tu equipo actual | **La boca física de TU equipo** por donde entró el anuncio | Te dice dónde está enchufado el cable de este lado (ej. `Gi1/0/24`) |
| **`Port ID` / `INTERFACE-NAME`** | En el detalle del vecino | **La boca física del EQUIPO VECINO** de la otra punta del cable | Te da la conexión exacta punta a punta: `Mi Gi1/0/24 <===> Su Puerto 25` |
| **`Device ID` / `IDENTITY`** | Tabla principal | El `hostname` o `/system identity` configurado en el equipo vecino | Si ves dos puertos tuyos distintos mostrando el mismo `Device ID` vecino, ¡hay dos cables hacia ese mismo switch (LACP o posible bucle)! |
| **`Capability (R, B, W, T, S)`** | LLDP / CDP | Rol del equipo: `R` = Router, `B` = Bridge/Switch, `W` = WiFi AP, `T` = Teléfono VoIP, `S` = Servidor/Estación | Permite distinguir al instante un switch de un teléfono IP o un Access Point |
| **`vlan99-mgmt,ether2`** | MikroTik (`INTERFACE`) | El anuncio llegó etiquetado dentro de la `vlan99-mgmt` que viaja sobre el puerto físico `ether2` | En MikroTik, como MNDP usa broadcast IP, un router también puede descubrir otros equipos que estén en la misma VLAN a través de un switch intermedio |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Querés saber a qué boca del switch está conectado un servidor Linux sin ir al rack

1. **Verificación rápida desde el servidor Linux:** `sudo lldpcli show neighbors` (o si aún no tiene `lldpd`, escuchar un anuncio durante 30–60 segundos con `sudo tcpdump -ni eth0 -s 1500 -vvv -c 1 'ether proto 0x88cc or ether host 01:00:0c:cc:cc:cc'`).
2. **Qué buscar en la salida:** El campo `SysName` (`SW-CORE`) y `PortID` (`Gi1/0/5`).
3. **Resultado:** Sabés en 10 segundos que el cable `eth0` del servidor entra exactamente en la boca 5 del switch `SW-CORE`.

### Síntoma 2: Alerta `%CDP-4-NATIVE_VLAN_MISMATCH` o `%CDP-4-DUPLEX_MISMATCH` en consola

1. **Interpretación:** CDP y LLDP no solo sirven para inventario; también incluyen en su anuncio cuál es la **Native VLAN / PVID** y el **Modo Duplex** de su puerto.
2. **Acción:** Si el Switch A tiene `native vlan 1` y el Switch B tiene `native vlan 99` en el mismo cable, CDP te avisa en el log antes de que te vuelvas loco buscando por qué se mezclan los tráficos sin etiquetar.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Rutina de Autodocumentación de Puertos:**
  - Después de cablear un rack o auditar una red nueva, ejecutá `show lldp neighbors` / `/ip neighbor print` y copiá la identidad de cada vecino en el comentario o descripción del puerto (`description UPLINK_SW-PISO2_P25` en Cisco o `comment="UPLINK_SW-PISO2_P25"` en MikroTik).
  - ¿Por qué? Porque si el martes que viene `SW-PISO2` se apaga por un corte eléctrico, **desaparecerá de la tabla de vecinos LLDP** (al vencer el `Hold-time` de 120 segundos), pero gracias a la `description` del puerto `Gi1/0/24` sabrás inmediatamente qué switch es el que acaba de caer.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Creer que si un equipo no aparece en `show cdp neighbors` el cable está cortado:** Acordate de que **CDP es propietario de Cisco**. Un switch TP-Link, un Aruba moderno con solo LLDP o una PC con Windows no hablan CDP. Ejecutá siempre **tanto `show lldp neighbors` como `show cdp neighbors`**.
- **❌ En MikroTik, olvidar que cuando agregás interfaces a un `bridge`, el tráfico MNDP se ve en la interfaz `bridge1` o en la `vlan`:** Si en `/ip neighbor discovery-settings` restringís el descubrimiento a una lista `MGMT`, asegurate de incluir en esa lista `MGMT` tanto al `bridge1` / `vlan99-mgmt` como a los puertos físicos troncales donde quieras escuchar LLDP de capa 2 pura.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar LLDP-MED (*Media Endpoint Discovery*) cuando hay teléfonos VoIP:** Si tenés teléfonos IP físicos que se conectan a la pared y de la parte trasera del teléfono sale un cable a la PC del empleado, **LLDP-MED** le dice automáticamente al teléfono: *"Vos hablá etiquetado en la `VLAN 30 (Voz)` con prioridad QoS 5, y dejá que la PC de atrás hable desnuda en la `VLAN 10 (Datos)`"* sin tener que configurar cada teléfono a mano.
- **Integrar LLDP con LibreNMS o NetBox:** Herramientas open-source como LibreNMS leen por SNMP la tabla `LLDP-MIB` de tus switches y dibujan el mapa interactivo de toda tu red automáticamente, avisándote si alguien cambia un cable de boca.

---

## 9. 🔗 Referencias internas

- [`netops-day-to-day-maintenance-and-observability`](../../concepts/netops-day-to-day-maintenance-and-observability.md) — Cómo encaja LLDP/CDP dentro de la operación y documentación viva del día a día
- [`ieee-and-ietf-networking-standards`](../../reference/ieee-and-ietf-networking-standards.md) — Resumen del estándar `IEEE 802.1AB (LLDP)`
- [`network-ports-protocols-and-multicast`](../../reference/network-ports-protocols-and-multicast.md) — Direcciones MAC multicast `01:80:C2:00:00:0E` (LLDP), `01:00:0C:CC:CC:CC` (CDP) y puerto `UDP 5678` (MNDP)
