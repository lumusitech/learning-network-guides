⬅️ [Volver a Guías](../README.md)

# Firewall Stateful y Segmentación por Zonas (ACLs, INPUT vs FORWARD) — Guía práctica multi-vendor

**Dominio:** `04-firewalls-nat-vpn`
**Nivel:** 🟡 Intermedio
**Estándares:** `RFC 2979`, `Netfilter / Conntrack`, `Cisco Zone-Based Firewall & Extended ACLs`
**Concepto base:** [`stateful-firewalls-and-zone-segmentation`](../../concepts/stateful-firewalls-and-zone-segmentation.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver reglas de INPUT y FORWARD con contadores de paquetes y listas de zonas
/ip firewall filter print stats
/interface list member print
/ip firewall address-list print

# Cisco IOS: Ver listas de control de acceso (ACLs) y cuántos paquetes coincidieron en cada línea (matches)
show access-lists
show ip interface Gi0/0.10 | include access list

# Linux (nftables): Ver el conjunto completo de tablas, cadenas y contadores de paquetes
sudo nft list ruleset
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

Cuando un router tiene 6 VLANs conectadas (`Admin`, `Staff`, `Servidores`, `DMZ`, `Cámaras CCTV`, `WiFi Invitados`), **por defecto el router enruta libremente entre todas ellas**: un visitante conectado al WiFi de Invitados o una cámara IP infectada puede conectarse al puerto `445 (SMB)` o `3389 (RDP)` del servidor de finanzas.

En esta guía implementamos una **Arquitectura de Firewall Stateful por Zonas (*Zero-Trust / Default Deny*)** donde:

1. **En la cadena `INPUT` (tráfico hacia el propio Router):** Solo la zona `MGMT` puede abrir SSH/WinBox; las demás VLANs internas solo pueden consultar `DNS (53)`, `DHCP (67)` y `NTP (123)`, y desde la `WAN` se bloquea todo.
2. **En la cadena `FORWARD` (tráfico que atraviesa el Router entre zonas):**
   - La regla #1 aprueba y acelera (`FastTrack`) las respuestas **`ESTABLISHED, RELATED`**.
   - `Staff` puede salir a Internet y entrar únicamente a los puertos de trabajo (`HTTPS 443`, `SMB 445`) de la zona `Servidores`.
   - El grabador `NVR` (`10.1.40.25`) puede iniciar conexiones hacia las `Cámaras CCTV`, **pero las cámaras no pueden iniciar conexiones ni a Internet ni a ninguna VLAN**.
   - `WiFi Invitados` solo puede salir a Internet (`WAN`) y tiene prohibido hablar con cualquier red interna.

> **🧠 Recordatorio del modelo mental:** Pensá en **`INPUT`** como la puerta blindada de la **cabina de los guardias (el propio Router)** y en **`FORWARD`** como el **molinete del hall central** por donde los usuarios cruzan de una sala a otra o salen a la calle. Gracias a la regla #1 **`ESTABLISHED, RELATED`**, cuando el NVR entra a la sala de las cámaras a buscar video (`NEW`), el guardia anota el permiso y deja volver el video de respuesta sin que las cámaras tengan llave para salir por su cuenta.

---

## 2. 🗺️ Topología de referencia

Las 6 zonas de seguridad que implementaremos en nuestros equipos:

```text
                        [Zona WAN: Internet (ether1-wan)]
                                       |
               +-----------------------------------------------+
               |            RTR-BORDE (Firewall)               |
               +-----------------------------------------------+
                 |          |          |            |          |
                 v          v          v            v          v
             [MGMT]     [STAFF]    [SERVERS]     [CCTV]     [GUEST]
             VLAN 99    VLAN 10     VLAN 40     VLAN 100    VLAN 200
           10.1.99.0/24 10.1.10.0  10.1.40.0   10.1.100.0  10.1.200.0/23
            (Admin IT)  (Usuarios) (NVR=.40.25) (Sin WAN!)  (Solo WAN!)
```

| Regla en `FORWARD` | Origen (`Quién inicia NEW`) | Destino (`A dónde va`) | Puertos permitidos | Acción |
|:------------------:|-----------------------------|------------------------|--------------------|:------:|
| **#1 y #2** | Cualquiera | Cualquiera | Conexiones ya abiertas (**`ESTABLISHED, RELATED`**) | ✅ `FastTrack` + `ACCEPT` |
| **#3** | Cualquiera | Cualquiera | Paquetes corruptos / sin sesión (**`INVALID`**) | ❌ `DROP` |
| **#4** | `MGMT` (`VLAN 99 / 20`) | Todas las Zonas | Todos (Soporte y administración) | ✅ `ACCEPT` |
| **#5** | `STAFF` (`VLAN 10`) | `SERVERS` (`VLAN 40`) | `TCP 443` (ERP HTTPS), `TCP 445` (NAS SMB) | ✅ `ACCEPT` |
| **#6** | `NVR` (`10.1.40.25`) | `CCTV` (`VLAN 100`) | `TCP/UDP 554` (RTSP), `TCP 80, 37777` | ✅ `ACCEPT` |
| **#7** | `STAFF`, `SERVERS`, `GUEST` | **`WAN` (Internet)** | Todos (o `80, 443, 53, 123` para `GUEST`) | ✅ `ACCEPT` |
| **#8** | `WAN` (Internet) | `SERVERS / DMZ` | Solo paquetes con Port Forwarding (**`dstnat`**) | ✅ `ACCEPT` |
| **#99 (Final)** | **Cualquiera** | **Cualquiera** | **Todo lo no autorizado arriba (ej. CCTV → WAN, Guest → LAN)** | 🛡️ **`DROP ALL`** |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Salvavidas obligatorio:** Antes de cargar la regla final `#99 (DROP ALL)`, activá **Safe Mode (`Ctrl+X`)** en MikroTik o `reload in 10` en Cisco.

### A. MikroTik RouterOS (v7+)

```text
# 1. Definir las Listas de Interfaces (Zonas limpias para no repetir reglas por subred):
/interface list
add name=WAN         comment="Proveedores de Internet"
add name=LAN-ALL     comment="Todas las VLANs internas (para DNS/DHCP/NTP)"
add name=MGMT        comment="Solo redes de Administradores IT"
add name=WAN-ALLOWED comment="VLANs que SI tienen permiso de salir a Internet (excluye CCTV!)"

/interface list member
add list=WAN         interface=ether1-wan
add list=LAN-ALL     interface=vlan99-mgmt
add list=LAN-ALL     interface=vlan10-staff
add list=LAN-ALL     interface=vlan40-servers
add list=LAN-ALL     interface=vlan100-cctv
add list=LAN-ALL     interface=vlan200-guest
add list=MGMT        interface=vlan99-mgmt
add list=WAN-ALLOWED interface=vlan99-mgmt
add list=WAN-ALLOWED interface=vlan10-staff
add list=WAN-ALLOWED interface=vlan40-servers
add list=WAN-ALLOWED interface=vlan200-guest
# (¡Observá que vlan100-cctv NO está en WAN-ALLOWED: las cámaras jamás saldrán a Internet!)

# 2. CADENA INPUT (Protección del propio Router):
/ip firewall filter
add chain=input connection-state=established,related,untracked action=accept comment="IN-1: Aceptar establecidas"
add chain=input connection-state=invalid action=drop comment="IN-2: Descartar invalidas"
add chain=input protocol=icmp action=accept comment="IN-3: Permitir ICMP Ping/PMTUD"
add chain=input in-interface-list=MGMT protocol=tcp dst-port=22,8291 action=accept comment="IN-4: SSH/WinBox SOLO desde MGMT"
add chain=input in-interface-list=LAN-ALL protocol=udp dst-port=53,67,123 action=accept comment="IN-5: DNS/DHCP/NTP para LANs"
add chain=input in-interface-list=LAN-ALL protocol=tcp dst-port=53 action=accept comment="IN-6: DNS TCP para LANs"
add chain=input action=drop comment="IN-99: DROP TODO EL RESTO HACIA EL ROUTER"

# 3. CADENA FORWARD (Segmentación Zero-Trust entre Zonas):
/ip firewall filter
add chain=forward connection-state=established,related action=fasttrack-connection hw-offload=yes comment="FWD-1: FastTrack establecidas"
add chain=forward connection-state=established,related,untracked action=accept comment="FWD-2: Aceptar establecidas"
add chain=forward connection-state=invalid action=drop comment="FWD-3: Descartar invalidas"
add chain=forward in-interface-list=MGMT action=accept comment="FWD-4: Admin IT llega a todas las zonas"
add chain=forward in-interface=vlan10-staff out-interface=vlan40-servers protocol=tcp dst-port=443,445 action=accept comment="FWD-5: Staff -> Servidores (ERP y SMB)"
add chain=forward src-address=10.1.40.25 out-interface=vlan100-cctv protocol=tcp dst-port=80,554,37777 action=accept comment="FWD-6: NVR -> Camaras CCTV"
add chain=forward in-interface-list=WAN-ALLOWED out-interface-list=WAN action=accept comment="FWD-7: Zonas autorizadas salen a Internet"
add chain=forward connection-nat-state=dstnat action=accept comment="FWD-8: Permitir Port Forwardings DNAT"
add chain=forward action=drop comment="FWD-99: DROP ZERO-TRUST (Bloquea CCTV->WAN, Guest->LAN, etc.)"
```

---

### B. Cisco IOS / Catalyst L3 (Extended ACLs Reflexivas / `established` en SVIs)

> **💡 Nota arquitectónica en Switches Cisco Capa 3:** Las ACLs extendidas en las interfaces `Vlan` de un switch Catalyst L3 se evalúan en el chip ASIC a velocidad de cable, pero son *Stateless* por defecto. Para permitir que el NVR (`10.1.40.25`) consulte a las cámaras (`10.1.100.0/24`) y que las cámaras **solo puedan devolver paquetes de respuesta TCP ya establecidos**, usamos la palabra clave **`established`** al tope de la ACL de las cámaras:

```cisco
configure terminal

! 1. ACL para la VLAN 100 (Cámaras CCTV):
!    - Permite que las cámaras respondan paquetes TCP ya iniciados por los Servidores (established)
!    - Permite consultar NTP al propio switch/router (10.1.100.1)
!    - Bloquea absolutamente todo intento de las cámaras de iniciar conexiones a la LAN o a Internet!
ip access-list extended ACL-IN-VLAN100-CCTV
 remark 1. Permitir respuestas TCP a conexiones iniciadas por el NVR
 permit tcp 10.1.100.0 0.0.0.255 host 10.1.40.25 established
 remark 2. Permitir sincronizar hora NTP contra su propio Gateway
 permit udp 10.1.100.0 0.0.0.255 host 10.1.100.1 eq 123
 remark 3. Bloquear todo el resto (ni LAN ni Internet)
 deny   ip any any log
exit

interface Vlan100
 ip access-group ACL-IN-VLAN100-CCTV in
exit

! 2. ACL para la VLAN 200 (WiFi Invitados — Solo salida a Internet, prohibido todo RFC 1918):
ip access-list extended ACL-IN-VLAN200-GUEST
 remark 1. Permitir DNS y DHCP hacia el propio Gateway (.200.1)
 permit udp 10.1.200.0 0.0.1.255 host 10.1.200.1 eq domain bootps
 remark 2. Prohibir acceso a cualquier red privada interna RFC 1918
 deny   ip 10.1.200.0 0.0.1.255 10.0.0.0 0.255.255.255 log
 deny   ip 10.1.200.0 0.0.1.255 172.16.0.0 0.15.255.255 log
 deny   ip 10.1.200.0 0.0.1.255 192.168.0.0 0.0.255.255 log
 remark 3. Permitir salida hacia Internet público (HTTP/HTTPS)
 permit tcp 10.1.200.0 0.0.1.255 any eq 80 443
 deny   ip any any
exit

interface Vlan200
 ip access-group ACL-IN-VLAN200-GUEST in
exit

end
write memory
```

---

### C. Linux (`nftables` — Firewall Stateful Moderno por Zonas con Sets de Interfaces)

```bash
cat << 'EOF' | sudo tee /etc/nftables.conf
#!/usr/sbin/nft -f
flush ruleset

define WAN_IFS = { "eth0" }
define MGMT_IFS = { "eth1.99" }
define LAN_ALL_IFS = { "eth1.10", "eth1.40", "eth1.99", "eth1.100", "eth1.200" }
define WAN_ALLOWED_IFS = { "eth1.10", "eth1.40", "eth1.99", "eth1.200" }

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop
        iifname "lo" accept
        ip protocol icmp accept

        # SSH solo desde VLAN 99 Management
        iifname $MGMT_IFS tcp dport 22 accept

        # DNS, DHCP y NTP para todas las VLANs internas
        iifname $LAN_ALL_IFS udp dport { 53, 67, 123 } accept
        iifname $LAN_ALL_IFS tcp dport 53 accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop

        # Admin IT llega a todo
        iifname $MGMT_IFS accept

        # Staff (VLAN 10) -> Servidores (VLAN 40) solo HTTPS y SMB
        iifname "eth1.10" oifname "eth1.40" tcp dport { 443, 445 } accept

        # NVR (10.1.40.25) -> Camaras CCTV (VLAN 100)
        ip saddr 10.1.40.25 oifname "eth1.100" tcp dport { 80, 554, 37777 } accept

        # Salida a Internet para zonas autorizadas (excluye Camaras CCTV!)
        iifname $WAN_ALLOWED_IFS oifname $WAN_IFS accept
    }
}
EOF

sudo nft -f /etc/nftables.conf
sudo systemctl enable --now nftables
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show access-lists ACL-IN-VLAN100-CCTV`)

```text
SW-CORE# show access-lists ACL-IN-VLAN100-CCTV
Extended IP access list ACL-IN-VLAN100-CCTV
    10 permit tcp 10.1.100.0 0.0.0.255 host 10.1.40.25 established (845210 matches)
    20 permit udp 10.1.100.0 0.0.0.255 host 10.1.100.1 eq ntp (142 matches)
    30 deny ip any any log (4512 matches)
```

### Tabla de interpretación de contadores

| Línea / Contador | Fabricante | Qué significa realmente | Diagnóstico inmediato |
|------------------|------------|-------------------------|-----------------------|
| **`(845210 matches)` en `permit ... established`** | Cisco / MikroTik / Linux | El flujo de video de las cámaras hacia el NVR está pasando con normalidad | ✅ Confirma que las respuestas a conexiones iniciadas por el NVR están permitidas |
| **`(4512 matches)` en `deny ip any any log` (`FWD-99`)** | Todos | Las cámaras IP intentaron conectarse 4.512 veces a servidores P2P en China/Internet y **el firewall las frenó en seco** | ✅ Es la prueba de por qué jamás hay que dejar la VLAN de cámaras/IoT con salida libre a Internet |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Un servicio nuevo en el servidor `10.1.40.10` no responde desde las PCs de `Staff (VLAN 10)` y querés saber en 10 segundos si lo está bloqueando el firewall

1. **Verificación científica sin desactivar el firewall:**
   - En MikroTik, mirá el contador de paquetes de la regla final `FWD-99 (DROP ZERO-TRUST)` mientras intentás conectarte desde la PC, o activá temporalmente `log=yes log-prefix="BLOQUEADO-FWD:"` en la regla `FWD-99`.
2. **Qué verás en `/log print follow where message~"BLOQUEADO-FWD"`:**
   - `BLOQUEADO-FWD: forward: in:vlan10-staff out:vlan40-servers, proto TCP (SYN), 10.1.10.50:54312->10.1.40.10:8080`.
   - En 1 línea el log te dice el puerto exacto (`TCP 8080`) que la aplicación necesitaba abrir en la regla `FWD-5` (y al terminar, apagás `log=no` en `FWD-99`).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Cómo insertar una regla nueva en la posición correcta en MikroTik CLI:**
  - Si hacés `/ip firewall filter add chain=forward ...` sin indicar posición, RouterOS agrega la regla **al final de todo (debajo del `DROP ALL` `#99`!)**, por lo que la regla nueva nunca se ejecutará.
  - Usá siempre **`place-before=[find comment~"FWD-99"]`** en CLI (o arrastrala en WinBox por encima de la regla final `DROP`).

---

## 7. ⚠️ Errores comunes en producción

- **❌ En Cisco IOS, olvidar qué significa `in` y `out` al aplicar `ip access-group` en una interfaz `interface Vlan10` (SVI):**
  - Ponete adentro del cerebro del Router/Switch L3:
    - **`in` (*Inbound* en `Vlan10`):** Es el tráfico que **sale de las PCs de la VLAN 10 y ENTRA hacia el Switch L3** para ir a otras redes. *(Acá es donde casi siempre querés filtrar: en el origen `in`, antes de que el router gaste recursos enrutando el paquete)*.
    - **`out` (*Outbound* en `Vlan10`):** Es el tráfico que viene de otras redes y **SALE del Switch L3 hacia las PCs de la VLAN 10**.
- **❌ Poner una regla de bloqueo arriba de `accept established,related`:** Salvo que quieras cortar de cuajo sesiones ya establecidas (o bloquear IPs de una lista negra de atacantes activos en `raw prerouting`), todas las políticas de zonas van **debajo** de `accept established,related` y `drop invalid`.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar la regla `connection-nat-state=dstnat action=accept` en `FORWARD` (Regla `FWD-8`):** En RouterOS v7, esta única regla permite automáticamente que pasen por `FORWARD` todos los puertos que vos hayas abierto deliberadamente en `/ip firewall nat` (`chain=dstnat`), evitando tener que escribir cada Port Forwarding dos veces (una en `NAT` y otra en `Filter`).

---

## 9. 🔗 Referencias internas

- [`stateful-firewalls-and-zone-segmentation`](../../concepts/stateful-firewalls-and-zone-segmentation.md) — El modelo mental completo de `INPUT` vs `FORWARD` vs `OUTPUT` y la matriz de 6 zonas
- [`nat-masquerade-dnat-and-hairpin`](nat-masquerade-dnat-and-hairpin.md) — Cómo publicar un servidor interno (`DNAT`) y resolver el acceso desde adentro de la oficina (*Hairpin NAT*)
- [`ipv4-cidr-vlsm-and-special-ranges`](../../reference/ipv4-cidr-vlsm-and-special-ranges.md) — Tabla de Wildcard Masks para escribir ACLs de Cisco sin errores
