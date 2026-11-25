⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: El Ping y Google funcionan, pero los bancos y sitios HTTPS pesados se congelan (Agujero Negro de MTU/MSS)

**Dominio:** `l3-routing`
**Nivel:** 🔴 Avanzado
**Capas OSI afectadas:** `Capa 3 (IP MTU / PMTUD)` y `Capa 4 (TCP MSS)`
**Equipos involucrados:** `MikroTik RouterOS`, `Cisco IOS`, `Linux / PPPoE / WireGuard / IPsec`

---

## 🎯 Problema

Se instala un nuevo proveedor de fibra por **PPPoE** (o un túnel VPN **WireGuard / IPsec** hacia Casa Central). Los usuarios reportan un síntoma desconcertante: **el `ping 8.8.8.8` responde en `4 ms`, las búsquedas de texto en Google abren al instante y pueden entrar por SSH, pero cuando intentan abrir el Home Banking, adjuntar un archivo en Outlook o cargar el sistema ERP web HTTPS, el navegador se queda "Cargando..." con la pantalla en blanco hasta dar Timeout**.

```text
[PC en LAN: MTU 1500] ---> [Router: PPPoE (MTU 1492) o VPN (MTU 1420)] ---> [Servidor Banco HTTPS: MTU 1500]
  1. Ping (64 bytes) --------------> Pasa perfecto (64 <= 1420) ----------> Responde OK!
  2. TCP SYN (Anuncia MSS=1460) ---> Pasa perfecto (60 <= 1420) ----------> Handshake OK!
  3. Banco envía Certificado TLS <-- X ¡Paquete de 1500B con DF=1 NO ENTRA en 1420B!
     (Si un firewall bloquea el aviso ICMP "Frag Needed", el paquete muere en silencio!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7: Probar ping de 1500 bytes vs 1400 bytes CON el bit Do-Not-Fragment activo
/ping 1.1.1.1 size=1500 do-not-fragment count=3
/ping 1.1.1.1 size=1400 do-not-fragment count=3

# Cisco IOS: Probar ping con df-bit en 1500 vs 1400 bytes
ping 1.1.1.1 size 1500 df-bit
ping 1.1.1.1 size 1400 df-bit

# Linux: Probar MTU 1500 (1472 payload + 28 headers = 1500) vs MTU 1420 (1392 + 28 = 1420)
ping -c 3 -M do -s 1472 1.1.1.1
ping -c 3 -M do -s 1392 1.1.1.1
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/ping 1.1.1.1 size=1500 do-not-fragment):
  SEQ HOST                                     SIZE TTL TIME       STATUS
    0 1.1.1.1                                                      packet too large and cannot be fragmented
    0 10.1.10.1                                 576  64 210us      fragmentation needed and DF set

# En Linux (ping -c 2 -M do -s 1472 1.1.1.1):
PING 1.1.1.1 (1.1.1.1) 1472(1500) bytes of data.
ping: local error: message too long, mtu=1420
```

**Interpretación de la evidencia:**

- El ping chico (`64B`) y el ping de `1400B` pasan en `4 ms`, pero el ping de `1500B` sin fragmentar falla con **`packet too large and cannot be fragmented` (`mtu=1420` o `1492`)**.
- Esto confirma al 100% un **Agujero Negro de MTU (*PMTUD Blackhole*)**: en el camino hay un enlace con MTU menor a 1500 (`PPPoE = 1492/1480`, `WireGuard = 1420`, `IPsec = 1400`) y las PCs de la LAN siguen pidiendo segmentos TCP de `MSS = 1460` (`MTU 1500`).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capa 7 — DNS o Certificados SSL):** El DNS resuelve en milisegundos y el handshake TCP (`SYN → SYN-ACK → ACK`) en el puerto 443 se completa. El corte ocurre exactamente en el primer paquete grande del servidor (el `TLS ServerHello` con el certificado de ~3000 bytes que viaja en paquetes al tope del MTU).
- **Causa raíz (Capas 3 y 4 — `MTU` vs `MSS`):** Los servidores en Internet envían todos sus paquetes TCP con el bit **`DF = 1` (*Don't Fragment*)**. Si la PC le pidió `MSS = 1460` en el paquete `SYN`, el servidor manda paquetes de `1500 bytes`. Cuando ese paquete choca con el cuello de botella de `1420 bytes` de tu VPN/PPPoE y algún firewall en Internet bloquea el aviso **`ICMP Type 3 Code 4 (Fragmentation Needed)`**, el servidor nunca se entera de que tiene que achicar el paquete y la conexión muere congelada.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **un puente ferroviario de `4,20 metros` de altura en la ruta (`MTU 1420`)**: las motos de mensajería (**el Ping y las búsquedas chicas**) pasan por debajo sin tocarlo, pero cuando la PC pide por teléfono un camión de mudanza de `4,60 metros` (**el `TCP SYN` con `MSS 1460`**), el camión queda **trabado contra el puente**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Encontrar por bisección cuál es el MTU real exacto del enlace o túnel

```text
# En MikroTik: Probar bajando el tamaño con do-not-fragment hasta que pase limpio:
/ping 1.1.1.1 size=1492 do-not-fragment count=2   # (Pasa en PPPoE estándar)
/ping 10.2.40.10 src-address=10.1.10.1 size=1420 do-not-fragment count=2   # (Pasa en WireGuard)
```

### 2. Verificar con `tcpdump` o `/tool sniffer` con qué `MSS` salen los paquetes `TCP SYN`

```bash
sudo tcpdump -ni eth0 'tcp[tcpflags] & tcp-syn != 0'
# Si ves 'options [mss 1460]' saliendo hacia un túnel de MTU 1420, ¡falta el MSS Clamping!
```

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/ip firewall mangle print
/interface print where mtu!=1500
```

### 2. Acción correctiva definitiva por fabricante (Activar **TCP MSS Clamping** + No bloquear ICMP)

El **TCP MSS Clamping** modifica al vuelo el paquete `TCP SYN` para que el `MSS` anunciado sea automáticamente **`MTU del enlace de salida - 40 bytes`**, solucionando el problema para todas las PCs sin tocar ni una sola computadora:

#### En MikroTik RouterOS v7

```text
# 1. Regla universal que ajusta automáticamente el MSS de todo paquete TCP SYN al MTU real del camino (clamp-to-pmtu):
/ip firewall mangle
add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu passthrough=yes comment="Clamp TCP MSS automatico al PMTU"

# 2. (Si usás IPsec por Políticas, que no crea una interfaz con MTU propio, forzar explícitamente MSS 1360):
add chain=forward ipsec-policy=out,ipsec protocol=tcp tcp-flags=syn tcp-mss=1361-65535 action=change-mss new-mss=1360 passthrough=yes
add chain=forward ipsec-policy=in,ipsec  protocol=tcp tcp-flags=syn tcp-mss=1361-65535 action=change-mss new-mss=1360 passthrough=yes
```

#### En Cisco IOS / IOS-XE

```cisco
configure terminal
! Aplicar en la interfaz Dialer (PPPoE) o Tunnel (VPN):
interface Tunnel0
 ip mtu 1400
 ip tcp adjust-mss 1360
exit
interface Dialer1
 ip mtu 1492
 ip tcp adjust-mss 1452
exit
end
write memory
```

#### En Linux (`nftables` / `iptables`)

```bash
# Con nftables:
sudo nft add rule inet filter forward tcp flags syn tcp option maxseg size set rt mtu

# Con iptables:
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

### 3. Rollback

```text
# MikroTik: /ip firewall mangle remove [find comment~"Clamp TCP MSS"]
# Cisco:    interface Tunnel0 -> no ip tcp adjust-mss
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] Los sitios HTTPS pesados, bancos y carpetas SMB a través de la VPN abren instantáneamente en `< 1 segundo`.
- [ ] El contador de paquetes de la regla `change-mss` en `/ip firewall mangle print stats` sube con cada nueva conexión TCP.
- [ ] **Cómo evitar que vuelva a ocurrir:** Incluir la regla de **`change-mss new-mss=clamp-to-pmtu`** y el permiso de **ICMP (`established,related` + `icmp`)** en tu plantilla base de todos los routers de borde.

---

## 🔗 Referencias

- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — Explicación conceptual completa de la fórmula `MSS = MTU - 40` y del *PMTUD Blackhole*
- [`wireguard-site-to-site-and-roadwarrior`](../../guides/04-firewalls-nat-vpn/wireguard-site-to-site-and-roadwarrior.md) — Configuración de MTU `1420` y MSS Clamping en túneles WireGuard
