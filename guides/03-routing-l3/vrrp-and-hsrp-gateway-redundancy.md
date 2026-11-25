⬅️ [Volver a Guías](../README.md)

# Alta Disponibilidad de Gateway (VRRP y HSRP) con WAN Tracking — Guía práctica multi-vendor

**Dominio:** `03-routing-l3`
**Nivel:** 🟡 Intermedio
**Estándares:** `RFC 5798 (VRRP v3)`, `RFC 3768 (VRRP v2)`, `Protocolo IP 112 (224.0.0.18)`, `Cisco HSRP v2`
**Concepto base:** [`first-hop-redundancy-vrrp-hsrp`](../../concepts/first-hop-redundancy-vrrp-hsrp.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver estado Master (RM) vs Backup (B), prioridad actual y VRID
/interface vrrp print
/interface vrrp print detail

# Cisco IOS: Ver estado de VRRP estándar o HSRP (Active vs Standby) y estado del Track Object WAN
show vrrp brief
show standby brief
show track

# Aruba / HP Capa 3: Ver instancias VRRP activas
show vrrp

# Linux (Keepalived): Ver estado del servicio y si la IP Virtual (VIP) está asignada a esta placa
systemctl status keepalived
ip -br addr show
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

Cuando instalás **dos routers de borde** (por ejemplo, `RTR-1` conectado al Proveedor de Fibra A y `RTR-2` conectado al Proveedor de Fibra B), las PCs de la empresa solo pueden tener **una única IP de Default Gateway (`10.1.10.1`)**.

En esta guía configuramos **VRRP (`RFC 5798`)** —el estándar universal abierto que permite poner en alta disponibilidad dos MikroTik, dos Cisco, dos Linux o incluso un Cisco como principal y un MikroTik como backup— junto con su pieza más importante y frecuentemente olvidada: el **Seguimiento de Salida a Internet (*WAN Tracking*)**, para que si al `RTR-1 (Master)` se le corta Internet en la calle, baje automáticamente su prioridad de `200` a `50` y le ceda el puesto de `Master` al `RTR-2` en segundos.

> **🧠 Recordatorio del modelo mental:** Pensá en VRRP como **la Ventanilla #1 (`VIP: 10.1.10.1`) y la gorra oficial (`MAC Virtual: 00:00:5E:00:01:0A`) compartidas por el Guardia Titular (`Prioridad 200`) y el Guardia Suplente (`Prioridad 100`)**. Si el Titular se desmaya (se apaga `RTR-1`) o si la calle detrás del Titular se inunda (**actúa el *WAN Tracking***), el Suplente se calza la misma gorra oficial y atiende la Ventanilla #1 sin que ningún empleado de la fábrica tenga que cambiar de fila.

---

## 2. 🗺️ Topología de referencia

Dos routers físicos (`RTR-1` y `RTR-2`) comparten la IP Virtual **`10.1.10.1`** (`VRID 10`) como Default Gateway para todas las PCs de la `VLAN 10`:

```text
    [ISP 1: Fibra Principal]                              [ISP 2: Fibra Backup]
               | (Ping check a 1.1.1.1)                              |
               v                                                     v
  +--------------------------+                          +--------------------------+
  |    RTR-1 (MASTER)        |                          |    RTR-2 (BACKUP)        |
  | IP Física: 10.1.10.2/24  |   Latidos 224.0.0.18     | IP Física: 10.1.10.3/24  |
  | Prioridad normal: 200    | <======================> | Prioridad fija:   100    |
  | (Si cae WAN 1 -> baja 50)|   (Protocolo IP 112)     |                          |
  +--------------------------+                          +--------------------------+
                    \                                            /
                     \                                          /
                      v                                        v
                +----------------------------------------------------+
                |        GATEWAY VIRTUAL COMPARTIDO (VRID 10)        |
                |        IP Virtual (VIP): 10.1.10.1                 |
                |        MAC Virtual:      00:00:5E:00:01:0A         |
                +----------------------------------------------------+
                                          ||
                                          v
                               [Switch Core — VLAN 10]
                                          |
                          [PCs y Servidores: Gateway = 10.1.10.1]
```

| Parámetro VRRP | Valor en `RTR-1 (Titular)` | Valor en `RTR-2 (Suplente)` |
|----------------|:--------------------------:|:---------------------------:|
| **IP Física Real en `vlan10`** | **`10.1.10.2/24`** | **`10.1.10.3/24`** |
| **IP Virtual Compartida (`VIP`)** | **`10.1.10.1`** (`/32` en MikroTik) | **`10.1.10.1`** (`/32` en MikroTik) |
| **Grupo VRRP (`VRID`) y Versión** | `vrid=10`, `version=3` | `vrid=10`, `version=3` |
| **Prioridad con WAN Sana** | **`200`** (Gana y es **`Master`**) | **`100`** (Escucha como **`Backup`**) |
| **Prioridad si cae WAN 1 (*WAN Tracking*)** | Baja a **`50`** (Cede el puesto a `RTR-2`) | Mantiene **`100`** (¡Pasa a ser **`Master`**!) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. MikroTik RouterOS v7 (VRRP + Firewall `Protocol 112` + WAN Tracking con Netwatch)

> **🚨 Dos reglas obligatorias en MikroTik VRRP:**
>
> 1. La IP física en `vlan10` lleva máscara **`/24`** (`10.1.10.2/24`), pero la IP Virtual (`VIP`) sobre la interfaz `vrrp10` **SIEMPRE lleva máscara `/32` (`10.1.10.1/32`)**.
> 2. En el Firewall, la cadena **`INPUT`** debe permitir el **Protocolo IP `112` (`vrrp`)**, y tus reglas de `FORWARD / NAT` deben incluir a `vrrp10` dentro de la lista `LAN` (`interface-list=LAN`), porque cuando las PCs hablan hacia Internet a través de la VIP, para el router el paquete entra por la interfaz **`vrrp10`**!

```text
# =====================================================================
# EN RTR-1 (TITULAR — IP Física 10.1.10.2/24, Prioridad inicial 200)
# =====================================================================
# 1. Permitir latidos VRRP (Protocolo IP 112) en la cadena INPUT del firewall:
/ip firewall filter
add chain=input protocol=vrrp in-interface-list=LAN action=accept place-before=[find action=drop] comment="Permitir latidos VRRP (Proto 112)"

# 2. Asignar la IP FÍSICA real (.2/24) a la interfaz vlan10-staff:
/ip address
add address=10.1.10.2/24 interface=vlan10-staff comment="IP Fisica RTR-1"

# 3. Crear la interfaz VRRP (vrid=10, priority=200) sobre vlan10-staff y agregarla a la lista LAN:
/interface vrrp
add name=vrrp10 interface=vlan10-staff vrid=10 version=3 priority=200 interval=1s preemption-mode=yes comment="VRRP VLAN 10"
/interface list member
add list=LAN interface=vrrp10

# 4. Asignar la IP VIRTUAL (.1) con máscara /32 sobre vrrp10:
/ip address
add address=10.1.10.1/32 interface=vrrp10 comment="VIP Default Gateway VLAN 10"

# 5. WAN TRACKING: Vigilar salida a Internet (1.1.1.1) por WAN 1.
#    Si cae Internet en RTR-1, baja la prioridad a 50 para que RTR-2 (100) tome el mando;
#    cuando vuelve Internet en RTR-1, restaura la prioridad a 200:
/ip route
add dst-address=1.1.1.1/32 gateway=<IP_GATEWAY_ISP1> scope=10 comment="Ruta fija de sonda WAN1"

/tool netwatch
add name="WAN1-VRRP-TRACKER" host=1.1.1.1 type=icmp interval=5s timeout=1s \
    down-script="/interface vrrp set [find name=vrrp10] priority=50; /log warning \"WAN1 CAIDA: VRRP degradado a prioridad 50\"" \
    up-script="/interface vrrp set [find name=vrrp10] priority=200; /log info \"WAN1 OK: VRRP restaurado a prioridad 200\""


# =====================================================================
# EN RTR-2 (SUPLENTE — IP Física 10.1.10.3/24, Prioridad fija 100)
# =====================================================================
/ip firewall filter
add chain=input protocol=vrrp in-interface-list=LAN action=accept place-before=[find action=drop] comment="Permitir latidos VRRP (Proto 112)"
/ip address
add address=10.1.10.3/24 interface=vlan10-staff comment="IP Fisica RTR-2"
/interface vrrp
add name=vrrp10 interface=vlan10-staff vrid=10 version=3 priority=100 interval=1s preemption-mode=yes comment="VRRP VLAN 10 Backup"
/interface list member
add list=LAN interface=vrrp10
/ip address
add address=10.1.10.1/32 interface=vrrp10 comment="VIP Default Gateway VLAN 10"
```

---

### B. Cisco IOS (Configuración con estándar abierto `VRRP` y equivalente en `HSRP v2` con `Track`)

#### En `RTR-1` Cisco usando **VRRP estándar** (compatible con MikroTik / Aruba / Linux)

```cisco
configure terminal

! 1. Sonda IP SLA + Track 1 para vigilar que Internet (1.1.1.1) responda por el ISP 1
ip route 1.1.1.1 255.255.255.255 203.0.113.1
ip sla 1
 icmp-echo 1.1.1.1
 frequency 5
ip sla schedule 1 life forever start-time now
track 1 ip sla 1 reachability

! 2. Configurar IP física (.2) y grupo VRRP 10 con VIP (.1), prioridad 200 y decremento de 150 si cae Track 1
interface GigabitEthernet0/1.10
 encapsulation dot1Q 10
 ip address 10.1.10.2 255.255.255.0
 vrrp 10 ip 10.1.10.1
 vrrp 10 priority 200
 vrrp 10 preempt
 vrrp 10 track 1 decrement 150
exit

! --- (Equivalente si ambos routers son Cisco y preferís usar Cisco HSRP v2): ---
! interface GigabitEthernet0/1.10
!  standby version 2
!  standby 10 ip 10.1.10.1
!  standby 10 priority 200
!  standby 10 preempt
!  standby 10 track 1 decrement 150

end
write memory
```

### C. Linux (`keepalived` — Estándar en Routers Linux / Firewalls / Balanceadores HA)

```bash
# 1. Instalar keepalived
sudo apt install -y keepalived

# 2. Configurar /etc/keepalived/keepalived.conf en RTR-1 (MASTER, priority 200 con chequeo WAN):
cat << 'EOF' | sudo tee /etc/keepalived/keepalived.conf
global_defs {
    enable_script_security
}
vrrp_script chk_wan {
    script "/usr/bin/ping -c 1 -W 1 1.1.1.1"
    interval 5
    fall 2
    rise 2
    weight -150
}
vrrp_instance VI_VLAN10 {
    state MASTER
    interface eth0.10
    virtual_router_id 10
    priority 200
    advert_int 1
    virtual_ipaddress {
        10.1.10.1/24
    }
    track_script {
        chk_wan
    }
}
EOF

sudo systemctl enable --now keepalived
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/interface vrrp print` en `RTR-1` y `RTR-2`)

```text
# Salida en RTR-1 (Titular activo):
[netops@RTR-1] > /interface vrrp print
Flags: R - RUNNING; M - MASTER
Columns: NAME, INTERFACE, MAC-ADDRESS, VRID, PRIORITY, INTERVAL, VERSION
#    NAME    INTERFACE     MAC-ADDRESS        VRID  PRIORITY  INTERVAL  VERSION
0 RM vrrp10  vlan10-staff  00:00:5E:00:01:0A    10       200  1s              3

# Salida en RTR-2 (Suplente en espera):
[netops@RTR-2] > /interface vrrp print
Flags: B - BACKUP
Columns: NAME, INTERFACE, MAC-ADDRESS, VRID, PRIORITY, INTERVAL, VERSION
#   NAME    INTERFACE     MAC-ADDRESS        VRID  PRIORITY  INTERVAL  VERSION
0 B vrrp10  vlan10-staff  00:00:5E:00:01:0A    10       100  1s              3
```

### En Cisco IOS (`show vrrp brief`)

```text
RTR-1# show vrrp brief
Interface          Grp Pri Time  Own Pre State   Master addr     Group addr
Gi0/1.10           10  200 3218       Y  Master  10.1.10.2       10.1.10.1
```

### Tabla de interpretación de columnas y flags

| Flag / Estado | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|---------------|------------|-------------------------|----------------------------|
| **`RM` (*Running, Master*) en RTR-1 y `B` (*Backup*) en RTR-2** | MikroTik | `RTR-1` tiene la VIP `.1` activa y responde al tráfico; `RTR-2` escucha sus latidos cada 1s en espera | ✅ Estado saludable normal |
| **`RM` en RTR-1 y TAMBIÉN `RM` en RTR-2** | Todos | 🚨 **Split-Brain (Doble Master):** ambos routers creen que son el jefe porque **no se están escuchando entre sí** | ❌ Revisar que el switch permita la VLAN entre ambos, que `INPUT` permita `protocol=vrrp` (`112`) y que coincida `version=3` |
| **`MAC-ADDRESS: 00:00:5E:00:01:0A`** | Estándar VRRP | Dirección MAC virtual del grupo `10` (`0A` en hexadecimal) | Es la MAC que verás en `arp -a` de todas las PCs para la IP `10.1.10.1` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En MikroTik cuando `RTR-1` es Master o hace failover a `RTR-2`, las PCs llegan por ping a `10.1.10.1`, pero no tienen Internet ni DNS

1. **Causa raíz (Olvidaste meter `vrrp10` en la lista de interfaces `LAN`):**
   - Cuando una PC envía tráfico a su Default Gateway `10.1.10.1`, el paquete **entra al MikroTik por la interfaz lógica `vrrp10`** (no por `vlan10-staff`).
   - Si tus reglas de firewall `INPUT` (para DNS) y `FORWARD` (para salir a `WAN`) dicen `in-interface-list=LAN` y **solo metiste a `vlan10-staff` en `LAN` pero te olvidaste de meter a `vrrp10` en `LAN`**, el firewall del router bloqueará todo el tráfico que entre por la IP virtual VRRP.
2. **Corrección inmediata:** `/interface list member add list=LAN interface=vrrp10` en ambos routers.

### Síntoma 2: ¿Dónde debe correr el Servidor DHCP cuando tengo dos routers con VRRP?

1. **Solución recomendada:**
   - **Nunca apuntes el servidor DHCP a la interfaz `vrrp10`** (porque en el router Backup la interfaz `vrrp10` está inactiva).
   - Configurá el Servidor DHCP sobre la interfaz base **`vlan10-staff`** en ambos routers entregando siempre como `gateway=10.1.10.1` (la VIP) y `dns-server=10.1.10.1`:
     - En `RTR-1`: tenelo activo con el rango `10.1.10.100–10.1.10.199` (o con `authoritative=yes`).
     - En `RTR-2`: podés darle el rango complementario `10.1.10.200–10.1.10.240` con un `delay-threshold=2s` para que `RTR-2` solo entregue IP si `RTR-1` no contestó en 2 segundos.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo pasar todo el tráfico de la empresa de `RTR-1` a `RTR-2` sin perder ni un ping antes de actualizar `RTR-1`:**
  1. Entrás a `RTR-1` y bajás su prioridad de `200` a `80`: `/interface vrrp set vrrp10 priority=80` (y deshabilitás temporalmente el Netwatch de tracking).
  2. En menos de 1 segundo, `RTR-2` (que tiene prioridad `100`) se convierte en `Master (RM)` y asume todo el tráfico de la empresa.
  3. Ahora podés actualizar el firmware de `RTR-1` y reiniciarlo en pleno horario laboral sin que nadie en la oficina lo note.
  4. Cuando `RTR-1` vuelve del reinicio y verificás que su WAN está sana, le devolvés `priority=200` y re-habilitás el Netwatch.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Poner máscara `/24` a la IP Virtual (`10.1.10.1/24`) en la interfaz `vrrp10` de MikroTik:** Repetilo como un mantra: en MikroTik, la interfaz física/VLAN lleva `/24` (`10.1.10.2/24`) y **la interfaz VRRP lleva siempre `/32` (`10.1.10.1/32`)**.
- **❌ Conectar ambos routers VRRP a un hipervisor VMware ESXi / Proxmox que tiene bloqueado *MAC Address Changes / Forged Transmits*:** Como VRRP presenta en la placa de red la dirección MAC virtual `00:00:5E:00:01:XX` (que es distinta a la MAC de la placa virtual asignada por el hipervisor), si el vSwitch del hipervisor tiene `Forged Transmits = Reject`, bloqueará los paquetes de la VIP. En las placas virtuales que hablen VRRP, habilitá siempre el permiso de MAC virtual en el hipervisor.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar siempre el mismo número en `VLAN ID`, `VRID` y nombre de interfaz:** Para la `VLAN 10`, usá `vrid=10` y `name=vrrp10`; para la `VLAN 40`, usá `vrid=40` y `name=vrrp40`.
- **Probar el failover trimestralmente:** Un sistema de alta disponibilidad que nunca se probó desconectando el cable WAN del Router 1 no es alta disponibilidad, es una expresión de deseo.

---

## 9. 🔗 Referencias internas

- [`first-hop-redundancy-vrrp-hsrp`](../../concepts/first-hop-redundancy-vrrp-hsrp.md) — Explicación conceptual completa de la MAC virtual, el Gratuitous ARP y el problema del Split-Brain
- [`dual-wan-failover-and-load-balancing`](dual-wan-failover-and-load-balancing.md) — Qué hacer cuando en lugar de 2 routers tenés los 2 proveedores de Internet conectados a un mismo router
- [`network-ports-protocols-and-multicast`](../../reference/network-ports-protocols-and-multicast.md) — Referencia del Protocolo IP `112` (VRRP), Multicast `224.0.0.18` y MAC `00:00:5E:00:01:XX`
