⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Migrar una empresa con red plana (`192.168.1.0/24`) a VLANs segmentadas sin frenar la operación

**Dominio:** `maintenance`
**Nivel:** 🔴 Avanzado
**Capas OSI afectadas:** `Capas 2, 3, 4 y 7 (Arquitectura completa)`
**Equipos involucrados:** `Router de Borde (MikroTik / Cisco / Linux)`, `Switches Gestionables`, `APs WiFi`

---

## 🎯 Problema

Heredás la red de una empresa de 80 empleados donde **absolutamente todo está mezclado en una única red plana `192.168.1.0/24` sobre la `VLAN 1`**: servidores de producción, PCs de administración, impresoras, 25 cámaras IP, relojes de control de personal y el WiFi que le dan a las visitas. El pool DHCP de 254 IPs se agota todos los mediodías y cualquier visitante tiene acceso directo a los servidores. Te piden **migrar toda la empresa a una arquitectura limpia por VLANs (`10.1.<VLAN>.0/24`) sin detener la facturación ni dejar la planta caída durante una semana**.

```text
ESTADO INICIAL (Caos en Red Plana):                 ESTADO OBJETIVO (Segmentado sin corte!):
+-----------------------------------------+         +---------------------------------------------+
|     TODO EN VLAN 1 (192.168.1.0/24)     |         | RTR-BORDE (Conviven VLAN 1 vieja + Nuevas!) |
|  - Router:      192.168.1.1             |  ====>  |  - VLAN 1 (Legado temporal): 192.168.1.1/24 |
|  - Servidores:  192.168.1.10..20        |         |  - VLAN 99 (Mgmt Switches):  10.1.99.1/24   |
|  - Cámaras:     192.168.1.50..75        |         |  - VLAN 40 (Servidores):     10.1.40.1/24   |
|  - PCs + WiFi:  192.168.1.100..254 (Lleno!)|      |  - VLAN 10 (Staff):          10.1.10.1/24   |
+-----------------------------------------+         |  - VLAN 100 (CCTV):          10.1.100.1/24  |
                                                    |  - VLAN 200 (WiFi Guest):    10.1.200.1/23  |
                                                    +---------------------------------------------+
```

---

## ⚡ Quick command (Auditoría Pre-Migración en 30 segundos)

```text
# 1. Inventariar todos los dispositivos vivos en la red vieja 192.168.1.0/24 (IP + MAC + Fabricante + Puerto del Switch):
# En el Router:
/ip arp print
/ip dhcp-server lease print
/ip neighbor print

# En los Switches:
show mac address-table
show lldp neighbors

# 2. Bajar el Lease Time del DHCP viejo (192.168.1.0/24) a 15 minutos el día anterior a la migración:
/ip dhcp-server set [find] lease-time=15m
```

---

## 🧠 Estrategia de Ingeniería: ¿Por qué una migración profesional NO se hace "de golpe" en una sola noche?

El secreto para migrar de una red plana a VLANs con **cero tiempo de inactividad (*Zero-Downtime*)** es la **Estrategia de Coexistencia Paralela**:

1. **La red vieja (`VLAN 1: 192.168.1.0/24`) NO se borra el Día 1.**
2. Primero construís todas las **VLANs nuevas (`10, 40, 99, 100, 200`)** con sus propios servidores DHCP, DNS y salida a Internet en el Router, y las pasás como **`Tagged`** por los cables entre el Router y los Switches, **mientras la `VLAN 1` sigue pasando exactamente como estaba y el firewall permite temporalmente que las VLANs nuevas hablen con `192.168.1.0/24`**.
3. Así, si hoy movés una sola PC de prueba (o el WiFi de Invitados) a la `VLAN 10` (`10.1.10.50`), **esa PC ya navega por Internet y sigue pudiendo imprimir y entrar a los servidores que todavía están en `192.168.1.10`!**
4. Migrás zona por zona en 5 etapas limpias y recién cuando `192.168.1.0/24` quedó con `0` equipos, apagás la red vieja y activás las reglas de bloqueo del Firewall Zero-Trust.

> **🧠 Modelo mental de la migración:** Pensá en esto como **construir la autopista nueva al lado del camino de tierra viejo con puentes de conexión entre ambos**: primero terminás de asfaltar todos los carriles nuevos (`VLANs 10, 40, 99, 100, 200`) sin cerrar el camino de tierra (`192.168.1.0/24`), después vas pasando de a un grupo de vehículos por vez al asfalto nuevo (primero los visitantes, luego las cámaras, luego las oficinas, al final los camiones pesados), y recién cuando ya no queda nadie en el camino de tierra, cerrás las vallas de seguridad entre los carriles.

---

## 🛠️ Procedimiento paso a paso (Runbook de Migración en 5 Etapas)

### Etapa 1 (Día 1 — Sin ningún corte): Preparar el Router y los Trunks en Coexistencia

1. **En el Router de Borde (`RTR-BORDE`):**
   - Mantener intacta la IP `192.168.1.1/24` sobre la VLAN 1 nativa.
   - Crear las interfaces `vlan10-staff` (`10.1.10.1/24`), `vlan40-servers` (`10.1.40.1/24`), `vlan99-mgmt` (`10.1.99.1/24`), `vlan100-cctv` (`10.1.100.1/24`) y `vlan200-guest` (`10.1.200.1/23`) con sus respectivos pools DHCP y salida NAT a Internet.
   - En el Firewall `FORWARD`, **no bloquear todavía el tráfico entre `10.1.0.0/16` y `192.168.1.0/24`** (solo aislar a `vlan200-guest`).
2. **En los Uplinks de los Switches (`Puerto 1`):**
   - Mantener `PVID = 1` (`Native VLAN 1`) para no cortar la red vieja, y **agregar como `Tagged` las VLANs `10, 40, 99, 100, 200`**.

### Etapa 2 (Día 1 — Alivio inmediato de IPs): Migrar el WiFi de Invitados y el WiFi Corporativo

1. En los puertos de los switches donde están conectados los Access Points WiFi, agregar como **`Tagged` las VLANs `10` y `200`**.
2. En el controlador WiFi, cambiar el SSID `"Empresa-Invitados"` para que use `VLAN ID = 200` y `"Empresa-Staff"` para que use `VLAN ID = 10`.
3. **Efecto inmediato en 30 segundos:** Los 120 celulares que saturaban la red vieja pasan a `10.1.200.x` y `10.1.10.x`, liberando la mitad del pool `192.168.1.0/24` sin haber cortado ni una sola PC de escritorio!

### Etapa 3 (Día 2): Migrar la Gestión de Switches/APs (`VLAN 99`) y las Cámaras IP (`VLAN 100`)

1. Asignar a cada switch y AP su nueva IP de administración en `10.1.99.x/24` (`VLAN 99`).
2. Cambiar el `PVID / access vlan` de las bocas de las 25 cámaras IP y del puerto secundario del NVR a la **`VLAN 100`** (`10.1.100.x/24`).

### Etapa 4 (Día 3 — Por departamento): Migrar las PCs de Usuarios e Impresoras (`VLAN 10`)

1. Como en la preparación bajaste el `lease-time` del DHCP viejo a `15 minutos`, para pasar un departamento entero de la red vieja a la nueva solo tenés que **cambiar el `PVID / access vlan` de sus bocas en el switch de `1` a `10`** (y reiniciar el puerto un segundo con `shutdown / no shutdown`).
2. La PC detecta reconexión de cable, pide DHCP en la `VLAN 10`, recibe `10.1.10.x/24` en 2 segundos y **sigue trabajando contra los servidores `192.168.1.10` a través del router sin enterarse**.
3. Para las impresoras de red, mejor aún: accedé por su nombre DNS interno (`impresora-contabilidad.empresa.local`) y movelas a `10.1.10.20x` con reserva DHCP.

### Etapa 5 (Ventana programada de 30 minutos): Migrar los Servidores (`VLAN 40`) y Cerrar el Firewall Zero-Trust

1. **Truco de oro para los Servidores (`192.168.1.10` → `10.1.40.10`):**
   - Movés el puerto del servidor a la `VLAN 40`, le ponés su nueva IP `10.1.40.10/24` (Gateway `10.1.40.1`) y actualizás el registro en el DNS interno (`/ip dns static set [find name=erp.empresa.local] address=10.1.40.10`).
   - **¿Y si había un programa viejo en alguna PC que tenía la IP `192.168.1.10` hardcodeada en un archivo `.ini`?**
     Mientras actualizás ese programa, podés poner en el Router una regla temporal de **`dst-nat` (`dst-address=192.168.1.10 action=dst-nat to-addresses=10.1.40.10`)**! Así incluso quien llame a la IP vieja `192.168.1.10` es redirigido transparentemente a la nueva IP `10.1.40.10`!
2. **Cierre final:**
   - Una vez que verificás con `/ip arp print where interface=vlan1` que ya no queda ningún equipo vivo en `192.168.1.0/24`, eliminás la IP `192.168.1.1` del router, convertís los enlaces entre switches en **Trunks Puros (`admit-only-vlan-tagged`)** y activás las reglas finales de bloqueo entre zonas en la cadena `FORWARD` del Firewall.

---

## 🧯 Mitigación y Rollback

### Rollback instantáneo de cualquier puesto o servidor durante la Etapa 4 o 5

Si al mover la boca `Gi1/0/15` de un equipo industrial o servidor de la `VLAN 1` a la `VLAN 40` algo en su software local falla:

```text
# Como la VLAN 1 vieja todavía sigue viva en el router durante toda la migración,
# el rollback de ese equipo tarda exactamente 3 segundos:
# Cisco:    interface Gi1/0/15 -> switchport access vlan 1
# MikroTik: /interface bridge port set [find interface=ether15] pvid=1
```

---

## ✅ Verificación post-mantenimiento

- [ ] `0` dispositivos activos en la antigua `VLAN 1` (`192.168.1.0/24` eliminada).
- [ ] Todos los enlaces entre switches y routers operan como Trunks 802.1Q sin usar la VLAN 1.
- [ ] La matriz de Firewall Stateful en `FORWARD` aísla `CCTV (VLAN 100)`, `Invitados (VLAN 200)`, `Staff (VLAN 10)`, `Servidores (VLAN 40)` y `Management (VLAN 99)`.
- [ ] Backup `.rsc` y `running-config` de la nueva arquitectura guardado y commiteado en Git.

---

## 🔗 Referencias

- [`vlans-8021q-access-trunk-pvid`](../../guides/02-switching-l2/vlans-8021q-access-trunk-pvid.md) — Configuración paso a paso de puertos Access, Trunk e Híbridos
- [`stateful-firewall-and-zone-acls`](../../guides/04-firewalls-nat-vpn/stateful-firewall-and-zone-acls.md) — Reglas finales del Firewall por Zonas una vez concluida la Etapa 5
- [`ipv4-cidr-vlsm-and-special-ranges`](../../reference/ipv4-cidr-vlsm-and-special-ranges.md) — Plantilla corporativa `10.<Sede>.<VLAN>.<Host>/24`
