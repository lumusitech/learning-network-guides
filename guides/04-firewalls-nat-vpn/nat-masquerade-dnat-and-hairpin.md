⬅️ [Volver a Guías](../README.md)

# NAT (Source NAT, Masquerade, Port Forwarding DNAT y Hairpin NAT) — Guía práctica multi-vendor

**Dominio:** `04-firewalls-nat-vpn`
**Nivel:** 🟡 Intermedio
**Estándares:** `RFC 3022 (Traditional NAT / NAPT)`, `Conntrack`
**Concepto base:** [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver reglas de NAT con contadores de paquetes y conexiones activas traducidas
/ip firewall nat print stats
/ip firewall connection print where connection-nat-state~"dstnat|srcnat"

# Cisco IOS: Ver tabla de traducciones activas (Inside Local <-> Inside Global) y estadísticas
show ip nat translations
show ip nat statistics

# Linux (nftables): Ver reglas de prerouting (DNAT) y postrouting (SNAT/Masquerade)
sudo nft list table ip nat
sudo conntrack -L -n
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

En toda red con direccionamiento privado (`RFC 1918`), el motor de **NAT** cumple tres misiones diarias:

1. **Source NAT (`srcnat` — `src-nat` vs `masquerade`):** Permite que todas tus PCs internas salgan a Internet compartiendo la IP pública de tu router. Aquí veremos por qué si tenés una **IP pública fija** debés usar **`action=src-nat`** en lugar de `masquerade`.
2. **Destination NAT (`dstnat` — *Port Forwarding*):** Permite que cuando un cliente externo desde Internet se conecte a tu IP Pública en el puerto `443` (o al puerto `37777` de un NVR), el router redirija ese tráfico hacia la IP privada del servidor interno (`10.1.40.10`).
3. **Hairpin NAT (*NAT Loopback*) + Exención de NAT para VPNs:** Cómo hacer que ese servidor publicado también sea accesible desde las PCs que están **adentro de la misma VLAN de la oficina** cuando usan la IP pública, y cómo evitar que la regla de `masquerade` rompa el tráfico de tus túneles VPN.

> **🧠 Recordatorio del modelo mental:** Pensá en **`dstnat` (*Prerouting*)** como el cartero en la puerta de entrada del edificio que mira el destinatario *antes* de consultar el mapa interno ("dice para el Edificio, pero puerto 443 es para la Oficina 40.10"), y en **`srcnat` (*Postrouting*)** como el sello que se estampa en el remitente *justo en el último segundo antes de salir a la calle*.

---

## 2. 🗺️ Topología de referencia

En los 3 fabricantes implementaremos salida a Internet, publicación del servidor web interno `10.1.40.10:443` y solución al *Hairpin NAT* para usuarios dentro de la misma red `10.1.40.0/24`:

```text
   [Cliente Externo en Internet]
                 |
                 | Pide ir a IP Pública 203.0.113.2:443
                 v
          (ether1-wan: 203.0.113.2)
   +-------------------------------------------+
   |                 RTR-BORDE                 |
   |  1. SRC-NAT: LANs -> Internet             |
   |  2. DST-NAT: 203.0.113.2:443 -> .40.10:443|
   |  3. HAIRPIN: .40.0/24 -> .40.10           |
   +-------------------------------------------+
          (vlan40: 10.1.40.1/24)
                 |
         +-------+-------+
         |               |
         v               v
 [Servidor Web]     [PC en la misma VLAN 40]
  10.1.40.10:443     10.1.40.50 (Entra a https://203.0.113.2)
```

| Escenario de NAT | Cadena (*Chain*) | Condición clave | Acción que ejecuta el Router |
|------------------|------------------|-----------------|------------------------------|
| **1. Salida a Internet (IP WAN Fija)** | `srcnat` (`POSTROUTING`) | `out-interface-list=WAN` | `src-nat to-addresses=203.0.113.2` |
| **2. Salida a Internet (IP WAN Dinámica)** | `srcnat` (`POSTROUTING`) | `out-interface-list=WAN` | `masquerade` |
| **3. Port Forwarding HTTPS (`443`)** | `dstnat` (`PREROUTING`) | `dst-address=203.0.113.2` (o `dst-address-type=local`) + `tcp 443` | `dst-nat to-addresses=10.1.40.10 to-ports=443` |
| **4. Hairpin NAT (LAN → IP Pública → LAN)** | `srcnat` (`POSTROUTING`) | `src-address=10.1.40.0/24` + `dst-address=10.1.40.0/24` | `masquerade` (obliga al servidor a contestar vía Router!) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. MikroTik RouterOS (v7+)

> **💡 Por qué en la regla de Port Forwarding (`dstnat`) usamos `dst-address=203.0.113.2` (o `dst-address-type=local dst-address=!10.0.0.0/8`) en vez de poner `in-interface-list=WAN`:**
> Si en tu regla de `dst-nat` ponés `in-interface-list=WAN`, el Port Forwarding funcionará perfecto para la gente que viene de **afuera** (Internet), pero **jamás funcionará para los empleados que están adentro de tu oficina (LAN)** porque sus paquetes entran al router por la interfaz `LAN`, no por la `WAN`!
> Al filtrar por **`dst-address=203.0.113.2`** (o `dst-address-type=local` si tu IP pública es dinámica), la misma regla de `dst-nat` captura tanto a los que vienen de Internet como a los que están adentro de la oficina.

```text
/ip firewall nat
# 1. (Opcional pero Vital si usás IPsec clásico por Políticas):
#    Eximir del NAT de Internet a los paquetes que van hacia la sucursal remota 10.2.0.0/16:
add chain=srcnat src-address=10.1.0.0/16 dst-address=10.2.0.0/16 action=accept comment="0. NAT Bypass para IPsec Site-to-Site"

# 2. SALIDA A INTERNET (Source NAT):
#    - Si tu IP pública WAN es FIJA (203.0.113.2), usá 'action=src-nat' (mucho más eficiente que masquerade):
add chain=srcnat out-interface-list=WAN action=src-nat to-addresses=203.0.113.2 comment="1. Salida a Internet (IP Publica Fija)"
#    - (Si tu IP WAN es DINÁMICA por DHCP/PPPoE, usá: add chain=srcnat out-interface-list=WAN action=masquerade)

# 3. HAIRPIN NAT (Para que las PCs dentro de la misma subred 10.1.40.0/24 puedan entrar al servidor 10.1.40.10 usando la IP pública):
add chain=srcnat src-address=10.1.40.0/24 dst-address=10.1.40.0/24 action=masquerade comment="2. Hairpin NAT (LAN hacia Servidor en misma LAN)"

# 4. PORT FORWARDING (Destination NAT — Publicar el puerto TCP 443 hacia el servidor 10.1.40.10):
#    - Si tu IP pública es FIJA (203.0.113.2):
add chain=dstnat dst-address=203.0.113.2 protocol=tcp dst-port=443 action=dst-nat to-addresses=10.1.40.10 to-ports=443 comment="3. Port Forward HTTPS hacia 10.1.40.10"

#    - (Alternativa universal si tu IP pública WAN cambia sola por DHCP/PPPoE y tenés DDNS):
#      'dst-address-type=local' significa "cualquier IP propia del router", y '!10.1.0.0/16' excluye la IP LAN del router
#      para que no intercepte el WebFig/HTTPS interno si lo usaras:
#      add chain=dstnat dst-address-type=local dst-address=!10.1.0.0/16 protocol=tcp dst-port=443 action=dst-nat to-addresses=10.1.40.10 to-ports=443
```

---

### B. Cisco IOS / IOS-XE (`ip nat inside` / `ip nat outside`)

```cisco
configure terminal

! 1. Marcar cuáles interfaces son internas (inside) y cuál es externa (outside)
interface GigabitEthernet0/0
 description WAN_INTERNET
 ip address 203.0.113.2 255.255.255.252
 ip nat outside
exit

interface GigabitEthernet0/1.10
 ip nat inside
exit
interface GigabitEthernet0/1.40
 ip nat inside
exit

! 2. Crear ACL que identifica qué redes internas tienen permiso de ser traducidas a Internet
!    (Excluyendo con 'deny' el tráfico entre sedes VPN si hay IPsec en la misma interfaz!)
ip access-list extended ACL-NAT-INTERNET
 deny   ip 10.1.0.0 0.0.255.255 10.2.0.0 0.0.255.255
 permit ip 10.1.0.0 0.0.255.255 any
exit

! 3. Activar Source NAT con sobrecarga de puertos (PAT / overload) sobre la interfaz WAN
ip nat inside source list ACL-NAT-INTERNET interface GigabitEthernet0/0 overload

! 4. Port Forwarding (Static PAT): redirigir el puerto TCP 443 de la IP pública hacia 10.1.40.10:443
ip nat inside source static tcp 10.1.40.10 443 203.0.113.2 443 extendable

end
write memory
```

---

### C. Linux (`nftables` — SNAT, DNAT y Hairpin NAT)

```bash
cat << 'EOF' | sudo tee -a /etc/nftables.conf
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;

        # Port Forwarding (DNAT): Tráfico dirigido a la IP pública 203.0.113.2:443 -> 10.1.40.10:443
        ip daddr 203.0.113.2 tcp dport 443 dnat to 10.1.40.10:443
    }

    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;

        # 1. Salida a Internet por eth0 (SNAT con IP fija o masquerade con IP dinámica)
        oifname "eth0" snat to 203.0.113.2

        # 2. Hairpin NAT (Cuando un host de 10.1.40.0/24 entró por la IP pública al servidor 10.1.40.10)
        ip saddr 10.1.40.0/24 ip daddr 10.1.40.10 tcp dport 443 masquerade
    }
}
EOF

sudo nft -f /etc/nftables.conf
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/ip firewall nat print stats`)

```text
[netops@RTR-BORDE] > /ip firewall nat print stats
Columns: CHAIN, ACTION, BYTES, PACKETS
# CHAIN   ACTION      BYTES      PACKETS
;;; 0. NAT Bypass para IPsec Site-to-Site
0 srcnat  accept      45120800   62100
;;; 1. Salida a Internet (IP Publica Fija)
1 srcnat  src-nat     892410000  741200
;;; 2. Hairpin NAT (LAN hacia Servidor en misma LAN)
2 srcnat  masquerade  1240500    1840
;;; 3. Port Forward HTTPS hacia 10.1.40.10
3 dstnat  dst-nat     18420100   19200
```

### En Cisco IOS (`show ip nat translations`)

```text
RTR-BORDE# show ip nat translations
Pro Inside global         Inside local          Outside local         Outside global
tcp 203.0.113.2:443       10.1.40.10:443        ---                   ---
tcp 203.0.113.2:54111     10.1.10.50:54111      142.250.1.1:443       142.250.1.1:443
```

### Tabla de interpretación de terminología Cisco NAT

| Término en Cisco (`show ip nat`) | Qué dirección IP es en lenguaje humano | Ejemplo en nuestra topología |
|----------------------------------|----------------------------------------|------------------------------|
| **`Inside local`** | **La IP privada real** de tu PC o servidor dentro de la empresa | `10.1.10.50` / `10.1.40.10` |
| **`Inside global`** | **Tu IP Pública WAN** con la que tu empresa se ve en Internet | `203.0.113.2` |
| **`Outside global` / `Outside local`** | La IP pública del servidor externo en Internet (ej. Google o un cliente externo) | `142.250.1.1` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Creaste la regla de Port Forwarding (`dst-nat`), pero desde afuera sigue dando *Connection Timed Out*

1. **Checklist de 4 puntos en 30 segundos (en este orden):**
   1. **¿Tenés IP Pública real o estás detrás de CGNAT?** Mirá la IP de tu interfaz WAN: si empieza con `100.64.x.x` a `100.127.x.x` (o `192.168.x.x` porque el módem del ISP no está en modo *Bridge*), el paquete jamás llega a tu router.
   2. **¿Sube el contador `PACKETS` de la regla `dstnat` cuando probás desde el celular por 4G?**
      - Si el contador de `dstnat` queda en **`0`**, el paquete no está llegando desde el proveedor (CGNAT, módem del ISP sin modo Bridge, o el ISP filtra ese puerto como el `25/80/445`).
      - Si el contador de `dstnat` **SÍ sube (`+1, +2, +3`)** pero igual no conecta, el problema está de tu router hacia adentro (Puntos 3 y 4):
   3. **¿El Firewall en la cadena `FORWARD` permite pasar paquetes `dstnat`?** Verificá que tengas la regla `chain=forward connection-nat-state=dstnat action=accept` antes del `drop` final.
   4. **¿El Servidor interno (`10.1.40.10`) tiene como Default Gateway a este router (`10.1.40.1`) y su firewall local encendido?** Si el servidor interno tiene otro gateway (o no tiene gateway), recibe el paquete pero no sabe por dónde devolver la respuesta.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **¿Por qué usar `action=src-nat` en lugar de `action=masquerade` cuando tu IP pública es fija?**
  - Cuando usás `action=masquerade`, cada vez que la interfaz WAN sufre un microcorte de 1 segundo, RouterOS o Linux **recorre toda la tabla Conntrack buscando miles de conexiones para purgarlas**, causando un pico de CPU del 100% en routers con mucho tráfico.
  - Con **`action=src-nat to-addresses=203.0.113.2`**, el router no tiene que recalcular ni purgar la tabla Conntrack ante un microcorte físico. Reservá `masquerade` únicamente para enlaces cuya IP WAN cambie dinámicamente.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Usar Hairpin NAT cuando podías usar *Split-Horizon DNS*:** Recordá que con **Hairpin NAT**, todo el tráfico entre una PC de la oficina y el servidor de la oficina tiene que **subir al router, ser traducido dos veces (`DNAT` + `SNAT`) por la CPU del router y volver a bajar al switch**, además de que en los logs del servidor web todas las PCs de la oficina aparecerán con la IP `.1` del router. Siempre que el acceso sea por nombre de dominio (`erp.empresa.com`), es 10 veces más rápido y limpio crear un registro estático en el DNS interno (`/ip dns static add name=erp.empresa.com address=10.1.40.10`) y dejar el Hairpin NAT solo como respaldo para apps que usan la IP pública hardcodeada.
- **❌ Hacer un Port Forwarding de `protocol=tcp` sin especificar `dst-address` (o `in-interface-list=WAN`) en el puerto `443` o `80`:** Si escribís `chain=dstnat protocol=tcp dst-port=443 action=dst-nat to-addresses=10.1.40.10` **sin poner a qué IP destino o interfaz se aplica**, cuando cualquier empleado de la oficina quiera abrir **`https://google.com:443`**, ¡tu router interceptará la salida a Internet en el puerto 443 y lo mandará a tu servidor local `10.1.40.10`, dejando a toda la empresa sin poder navegar ninguna web HTTPS!

---

## 8. ✅ Buenas prácticas profesionales

- **Nunca exponer puertos de administración (`3389 RDP`, `22 SSH`, `445 SMB`, `5432 PostgreSQL`, `37777 Dahua`) abiertos a todo `0.0.0.0/0` en `dstnat`:** Para acceder a servidores internos, cámaras o escritorios remotos desde afuera, levantá un túnel **WireGuard** con la guía siguiente ([`wireguard-site-to-site-and-roadwarrior.md`](wireguard-site-to-site-and-roadwarrior.md)). Y si un proveedor externo exige un Port Forwarding puntual, restringilo siempre con **`src-address-list=IPS-PROVEEDOR-AUTORIZADO`**.

---

## 9. 🔗 Referencias internas

- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — El diagrama completo de la tabla Conntrack y del "Triángulo Roto" del Hairpin NAT
- [`stateful-firewalls-and-zone-segmentation`](stateful-firewall-and-zone-acls.md) — Cómo se coordina la tabla `nat` con la cadena `forward` (`connection-nat-state=dstnat`)
- [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md) — Cómo configurar *Split-Horizon DNS* para evitar el costo del Hairpin NAT
