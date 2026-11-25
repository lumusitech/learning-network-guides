⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: El túnel VPN Site-to-Site (WireGuard o IPsec) figura conectado (`UP`), pero no pasa tráfico entre las redes de ambas sedes

**Dominio:** `security-vpn`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 3 (Routing / AllowedIPs)` y `Capa 4 (NAT Bypass / FastTrack / Firewall)`
**Equipos involucrados:** `MikroTik RouterOS v7`, `Cisco IOS-XE`, `Linux WireGuard / strongSwan`

---

## 🎯 Problema

Levantaste un túnel VPN Site-to-Site (**WireGuard** o **IPsec IKEv2**) entre **Casa Central (`10.1.0.0/16`)** y la **Sucursal 2 (`10.2.0.0/16`)**. En ambos routers el túnel figura **`Established` / `Last Handshake: 15s`**, pero cuando hacés `ping` desde una PC de Casa Central (`10.1.10.50`) al servidor de la Sucursal 2 (`10.2.40.10`), da **`Request Timed Out`**.

```text
+-----------------------------------+       Túnel WireGuard / IPsec UP!       +-----------------------------------+
|      RTR-SEDE1 (Casa Central)     | <=====================================> |      RTR-SEDE2 (Sucursal 2)       |
|  LAN: 10.1.0.0/16                 |   Handshake OK! / Phase 2 Established!  |  LAN: 10.2.0.0/16                 |
|                                   |   ¿Por qué no llega el Ping de la PC?   |                                   |
|  ¡Porque una regla de MASQUERADE  |   1) Masquerade sin out-interface=WAN   |  3) Falta ruta de vuelta a 10.1.x |
|   sin filtro WAN o el FastTrack   |   2) Falta 10.2.0.0/16 en AllowedIPs    |  4) Firewall FORWARD lo bloquea   |
|   se está comiendo el paquete!    |                                         |                                   |
+-----------------------------------+                                         +-----------------------------------+
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7: Capturar en vivo con el sniffer a dónde va realmente el paquete hacia 10.2.40.10!
/tool sniffer quick ip-address=10.2.40.10
/ip firewall nat print
/ip route check 10.2.40.10

# Si es WireGuard: Verificar que allowed-address incluya las subredes LAN y no solo la IP /32 del túnel!
/interface wireguard peers print detail

# Si es IPsec IKEv2: Verificar contadores de installed-sa y si existe la regla #0 de NAT Bypass!
/ip ipsec installed-sa print
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás con `/tool sniffer quick ip-address=10.2.40.10` durante el incidente (Los 2 culpables clásicos)

```text
# CULPABLE A (El paquete entra al túnel wg-sedes, pero con la IP origen CAMBIADA por el NAT!):
INTERFACE    TIME   NUM  DIR  SRC-ADDRESS          DST-ADDRESS          PROTOCOL
vlan10       0.510    1  <-   10.1.10.50           10.2.40.10           ip:icmp
wg-sedes     0.510    2  ->   10.0.255.1           10.2.40.10           ip:icmp   <-- ¡Mal! (O peor: sale con la IP pública 203.0.113.2!)

# CULPABLE B (En IPsec: el paquete ni siquiera entra al túnel, ¡sale directo por ether1-wan hacia Internet!):
INTERFACE    TIME   NUM  DIR  SRC-ADDRESS          DST-ADDRESS          PROTOCOL
vlan10       0.812    1  <-   10.1.10.50           10.2.40.10           ip:icmp
ether1-wan   0.812    2  ->   203.0.113.2          10.2.40.10           ip:icmp   <-- ¡Se escapó a la WAN por falta de NAT Bypass!
```

**Interpretación de la evidencia:**

- **En el Culpable A (WireGuard):** El paquete salió por `wg-sedes` con la IP `203.0.113.2` (porque tenés una regla de `masquerade` general sin `out-interface-list=WAN`), y cuando llega a la Sucursal 2, WireGuard en la Sucursal 2 lo **descarta en el acto** porque `203.0.113.2` no está en su lista de `allowed-address` (o bien te olvidaste de incluir `10.1.0.0/16` en `allowed-address` de la Sucursal 2!).
- **En el Culpable B (IPsec por Políticas):** En IPsec clásico, si no ponés en el **puesto #0 de `/ip firewall nat`** la regla de **NAT Bypass (`src-address=10.1.0.0/16 dst-address=10.2.0.0/16 action=accept`)**, la regla de `masquerade` de Internet le cambia la IP origen a `203.0.113.2` *antes* de que se evalúen las políticas IPsec. Como la política IPsec buscaba origen `10.1.0.0/16`, ya no coincide y el paquete se escapa sin cifrar hacia el módem de Internet!

---

## 🧠 Diagnóstico por capas

Lista de verificación en orden estricto para destrabar cualquier túnel VPN en 2 minutos:

1. **¿Qué pasa con el NAT (`srcnat`)?** Asegurar que el tráfico entre `10.1.0.0/16` y `10.2.0.0/16` **NO sufra NAT**.
2. **¿Qué pasa con las Rutas y Selectores (`AllowedIPs` / `IPsec Policy`)?**
   - En **WireGuard**: Ambos routers deben tener en `allowed-address` del peer la subred LAN del otro lado **Y** tener la ruta en `/ip route`.
   - En **IPsec**: Además del NAT Bypass, el tráfico IPsec debe estar exento del **`FastTrack`** en `filter forward`.
3. **¿Qué pasa con el Firewall `FORWARD` (y el firewall de Windows del servidor destino)?**
   - Un servidor Windows con el perfil de red por defecto bloquea el ping que viene desde una subred distinta a su propia `/24` local! (Probar siempre haciendo ping primero a la **IP LAN del Router remoto `10.2.10.1`** antes de probar a una PC Windows).

> **🧠 Modelo mental del incidente:** Pensá en la falta de *NAT Bypass* como **un empleado de correo interno que le pega una estampilla de correo internacional a una carpeta que iba para la Sucursal 2**: apenas tiene la estampilla pública pegada, la tiran en el buzón de la calle en lugar de subirla al furgón interno de la empresa.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Probar primero ping hacia la IP LAN interna del Router remoto (`10.2.10.1`) especificando la IP LAN local (`src-address=10.1.10.1`)

```text
# Desde RTR-SEDE1:
/ping 10.2.10.1 src-address=10.1.10.1 count=3
```

- Si nunca ponés `src-address=10.1.10.1`, el router usa como origen la IP del túnel o de la WAN y la prueba te engaña.

### 2. Correr `/tool sniffer quick ip-address=10.2.10.1` en ambos routers a la vez mientras corre el ping

- Mirá en `RTR-SEDE1`: ¿El paquete sale (`->`) con `SRC-ADDRESS: 10.1.10.1` intacta?
- Mirá en `RTR-SEDE2`: ¿El paquete entra (`<-`) y sale un paquete de respuesta (`->`)?

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/ip firewall nat print
/ip firewall filter print where chain=forward
```

### 2. Acción correctiva por tecnología VPN

#### A. Si el túnel es **WireGuard** (En MikroTik / Linux)

```text
# 1. En AMBOS routers: Asegurar que la regla de Masquerade de Internet solo actúe cuando sale por la lista WAN!
/ip firewall nat
set [find action=masquerade] out-interface-list=WAN

# 2. En RTR-SEDE1: Verificar que el Peer de Sucursal 2 tenga '10.2.0.0/16' en allowed-address y su ruta en /ip route:
/interface wireguard peers
set [find comment~"Sucursal 2"] allowed-address=10.0.255.2/32,10.2.0.0/16
/ip route
add dst-address=10.2.0.0/16 gateway=10.0.255.2

# 3. En RTR-SEDE2: Verificar el espejo exacto ('10.1.0.0/16' en allowed-address y ruta hacia 10.0.255.1):
/interface wireguard peers
set [find comment~"Casa Central"] allowed-address=10.0.255.0/24,10.1.0.0/16
/ip route
add dst-address=10.1.0.0/16 gateway=10.0.255.1

# 4. En AMBOS routers: Permitir que el tráfico del túnel cruce la cadena FORWARD del Firewall:
/interface list member
add list=LAN interface=wg-sedes
/ip firewall filter
add chain=forward in-interface=wg-sedes out-interface-list=LAN action=accept place-before=[find action=drop] comment="Permitir trafico VPN WireGuard"
add chain=forward in-interface-list=LAN out-interface=wg-sedes action=accept place-before=[find action=drop] comment="Permitir salida a VPN WireGuard"
```

#### B. Si el túnel es **IPsec IKEv2 por Políticas** (En MikroTik / Cisco)

```text
# 1. En el PUESTO #0 (Arriba de todo en /ip firewall nat): Agregar el NAT Bypass!
/ip firewall nat
add chain=srcnat src-address=10.1.0.0/16 dst-address=10.2.0.0/16 action=accept place-before=0 comment="0. NAT Bypass IPsec"

# 2. En /ip firewall filter (Arriba de la regla de fasttrack-connection!): Agregar el FastTrack Bypass para IPsec!
/ip firewall filter
add chain=forward ipsec-policy=in,ipsec  action=accept place-before=[find action=fasttrack-connection] comment="IPsec In Bypass FastTrack"
add chain=forward ipsec-policy=out,ipsec action=accept place-before=[find action=fasttrack-connection] comment="IPsec Out Bypass FastTrack"

# 3. Limpiar entradas viejas de Conntrack que habían quedado cacheadas con NAT:
/ip firewall connection remove [find dst-address~"10.2."]
```

### 3. Rollback

```text
# Si un servidor destino en la Sucursal 2 no tiene Default Gateway configurado y no podés tocarlo hoy,
# solo en ese caso de emergencia hacés un src-nat/masquerade al salir hacia él para que vea la IP local del router de la Sucursal 2.
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `/ping 10.2.10.1 src-address=10.1.10.1` responde en `< 15 ms` con `0%` de pérdida.
- [ ] En `/tool sniffer`, los paquetes viajan de punta a punta conservando sus IPs privadas originales (`10.1.10.50 → 10.2.40.10`) para trazabilidad de auditoría.
- [ ] **Cómo evitar que vuelva a ocurrir:** **Jamás escribir una regla de `masquerade` o `src-nat` sin el filtro `out-interface-list=WAN`**, y después de crear una regla de *NAT Bypass* para IPsec, limpiar siempre las conexiones viejas en `/ip firewall connection`.

---

## 🔗 Referencias

- [`wireguard-site-to-site-and-roadwarrior`](../../guides/04-firewalls-nat-vpn/wireguard-site-to-site-and-roadwarrior.md) — Guía completa de configuración de WireGuard Site-to-Site
- [`ipsec-ikev2-site-to-site`](../../guides/04-firewalls-nat-vpn/ipsec-ikev2-site-to-site.md) — Guía completa de configuración de IPsec IKEv2 con NAT Bypass y FastTrack Bypass
