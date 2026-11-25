⬅️ [Volver a Guías](../README.md)

# VPNs con WireGuard: Site-to-Site entre Sedes y Roadwarrior — Guía práctica multi-vendor

**Dominio:** `04-firewalls-nat-vpn`
**Nivel:** 🟡 Intermedio
**Estándares:** `WireGuard (Noise Protocol Framework: ChaCha20-Poly1305, Curve25519, BLAKE2s)`, `UDP 51820`
**Concepto base:** [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# MikroTik RouterOS v7: Ver interfaces WireGuard (su clave pública) y estado de los Peers (last-handshake)
/interface wireguard print
/interface wireguard peers print detail

# Linux: Ver estado criptográfico del túnel, IPs permitidas, último handshake y bytes transferidos
sudo wg show

# Probar conectividad y MTU máximo sin fragmentar a través del túnel WireGuard (MTU 1420 -> Ping 1392 en Linux)
ping -c 3 -M do -s 1392 10.2.40.10
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

**WireGuard** revolucionó las redes privadas virtuales (VPN): incluido de forma nativa en el kernel **Linux** y en **MikroTik RouterOS v7+**, reemplaza la enorme complejidad de OpenVPN e IPsec clásico por una interfaz de red Capa 3 ultra-rápida que funciona exactamente igual que las claves SSH:

1. Cada extremo genera automáticamente un **par de claves (`Private Key` + `Public Key`)**.
2. Solo intercambiás las **Claves Públicas** entre ambos routers y definís qué subredes IP tienen permiso de viajar por ese peer (**`AllowedIPs` / `allowed-address`**).
3. Es **100% silencioso ante escaneos de puertos** (si un atacante manda un paquete UDP al puerto `51820` sin tu clave criptográfica, WireGuard ni siquiera devuelve un byte de respuesta) y **atraviesa CGNAT sin esfuerzo**: basta con que **una sola de las dos sedes** tenga IP pública para que la sucursal detrás de CGNAT se conecte usando `persistent-keepalive=25s`.

> **🧠 Recordatorio del modelo mental:** Pensá en `AllowedIPs` (`allowed-address`) de WireGuard como **una tabla que cumple DOS funciones a la vez**:
>
> 1. **Al SALIR hacia el túnel (*Selector de Ruta*):** *"¿A cuál de mis peers de esta interfaz WireGuard le tengo que encriptar y mandar los paquetes destinados a `10.2.0.0/16`?"*
> 2. **Al ENTRAR desde el túnel (*Filtro Anti-Spoofing*):** *"¿Este peer que acaba de desencriptar un paquete tiene permiso para enviarme paquetes con IP Origen `10.2.0.0/16`?"* (Si una subred no está en su lista `allowed-address`, WireGuard descarta el paquete al instante).

---

## 2. 🗺️ Topología de referencia

Uniremos **Casa Central (`Sede 1: MikroTik v7` con IP pública `203.0.113.2`)** con **Sucursal 2 (`MikroTik o Linux`, incluso si está detrás de CGNAT)** y con la **Laptop del Administrador (*Roadwarrior*)**:

```text
+-----------------------------------+        Túnel WireGuard (UDP 51820)        +-----------------------------------+
|     RTR-SEDE1 (Casa Central)      |        Subred Túnel: 10.0.255.0/24        |    RTR-SEDE2 (Sucursal / Linux)   |
|  WAN Pública: 203.0.113.2:51820   | <=======================================> |  WAN: Dinámica o detrás de CGNAT! |
|  IP Túnel wg0: 10.0.255.1/24      |        MTU = 1420 | MSS Clamp = 1380      |  IP Túnel wg0: 10.0.255.2/24      |
|  LAN Sede 1:   10.1.0.0/16        |                                           |  LAN Sede 2:   10.2.0.0/16        |
+-----------------------------------+                                           +-----------------------------------+
                  ^
                  |  Conexión Roadwarrior (Admin IT remoto)
                  +--- [Laptop Ingeniero: IP Túnel 10.0.255.100/32]
```

| Extremo | IP dentro del Túnel (`wg0`) | Subredes que anuncia (`allowed-address` vistas desde el otro lado) | ¿Inicia conexión o espera? |
|---------|:---------------------------:|--------------------------------------------------------------------|----------------------------|
| **`RTR-SEDE1` (Central)** | **`10.0.255.1/24`** | `10.0.255.1/32, 10.1.0.0/16` | Escucha en `203.0.113.2:51820` |
| **`RTR-SEDE2` (Sucursal)** | **`10.0.255.2/24`** | `10.0.255.2/32, 10.2.0.0/16` | Conecta a `203.0.113.2:51820` (`keepalive 25s`) |
| **`Laptop Admin` (Roadwarrior)** | **`10.0.255.100/32`** | `10.0.255.100/32` | Conecta bajo demanda desde cualquier WiFi/4G |

---

## 3. 🛠️ Configuración paso a paso por fabricante

### A. En `RTR-SEDE1` (Casa Central — MikroTik RouterOS v7 con IP Pública)

```text
# 1. Crear la interfaz WireGuard (RouterOS genera su clave privada y pública automáticamente!)
/interface wireguard
add name=wg-sedes listen-port=51820 mtu=1420 comment="Concentrador WireGuard Sedes y Admin"

# 2. Ver cuál es la Clave Pública generada en RTR-SEDE1 para copiarla a la Sucursal 2 y a tu Laptop:
/interface wireguard print

# 3. Asignar la IP del túnel (10.0.255.1/24) e incorporar wg-sedes a la lista LAN (o MGMT):
/ip address
add address=10.0.255.1/24 interface=wg-sedes comment="IP Concentrador WireGuard"
/interface list member
add list=LAN interface=wg-sedes

# 4. Abrir el puerto UDP 51820 en la cadena INPUT del Firewall para que entren los túneles desde Internet:
/ip firewall filter
add chain=input protocol=udp dst-port=51820 action=accept place-before=[find action=drop] comment="Permitir entrada WireGuard UDP 51820"

# 5. Dar de alta como Peer a la SUCURSAL 2 (pegando la public-key de RTR-SEDE2)
#    ¡OJO! En 'allowed-address' incluimos TANTO la IP de túnel (.2/32) COMO toda la LAN de la Sucursal 2 (10.2.0.0/16):
/interface wireguard peers
add interface=wg-sedes \
    public-key="PEGAR_AQUI_PUBLIC_KEY_DE_RTR_SEDE2=" \
    allowed-address=10.0.255.2/32,10.2.0.0/16 \
    comment="Peer Sucursal 2"

# 6. Dar de alta como Peer a la LAPTOP DEL ADMINISTRADOR (Roadwarrior — IP única .100/32):
add interface=wg-sedes \
    public-key="PEGAR_AQUI_PUBLIC_KEY_DE_LA_LAPTOP=" \
    allowed-address=10.0.255.100/32 \
    comment="Laptop Admin NetOps"

# 7. Agregar la ruta en la tabla de enrutamiento de Casa Central hacia la LAN de la Sucursal 2:
/ip route
add dst-address=10.2.0.0/16 gateway=10.0.255.2 comment="Ruta a Sucursal 2 por WireGuard"

# 8. Asegurar la regla de TCP MSS Clamping para evitar que páginas HTTPS o archivos SMB se congelen en MTU 1420:
/ip firewall mangle
add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu comment="Clamp TCP MSS al MTU del tunel"
```

---

### B. En `RTR-SEDE2` (Sucursal 2 — Opción 1: en MikroTik RouterOS v7, incluso detrás de CGNAT)

```text
# 1. Crear la interfaz WireGuard en la Sucursal 2 y asignarle la IP 10.0.255.2/24
/interface wireguard
add name=wg-sedes listen-port=51820 mtu=1420 comment="Tunel hacia Casa Central"
/ip address
add address=10.0.255.2/24 interface=wg-sedes
/interface list member
add list=LAN interface=wg-sedes

# 2. Configurar el Peer apuntando a la IP pública de Casa Central (203.0.113.2:51820)
#    con 'persistent-keepalive=25s' para mantener abierto el NAT/CGNAT de la sucursal las 24 hs!
/interface wireguard peers
add interface=wg-sedes \
    public-key="PEGAR_AQUI_PUBLIC_KEY_DE_RTR_SEDE1=" \
    endpoint-address=203.0.113.2 \
    endpoint-port=51820 \
    allowed-address=10.0.255.0/24,10.1.0.0/16 \
    persistent-keepalive=25s \
    comment="Conexion permanente a Casa Central"

# 3. Agregar la ruta hacia las redes de Casa Central (10.1.0.0/16):
/ip route
add dst-address=10.1.0.0/16 gateway=10.0.255.1 comment="Ruta a Casa Central por WireGuard"
```

---

### C. En `RTR-SEDE2` o Servidor en la Nube — Opción 2: en Linux (`wg-quick` / `/etc/wireguard/wg0.conf`)

```bash
# 1. Instalar herramientas de WireGuard y generar el par de claves
sudo apt install -y wireguard
umask 077
wg genkey | tee /tmp/wg_private.key | wg pubkey > /tmp/wg_public.key
cat /tmp/wg_public.key   # <-- Copiar esta clave pública y pegarla en RTR-SEDE1

# 2. Crear /etc/wireguard/wg0.conf (wg-quick agrega automáticamente las rutas de AllowedIPs!)
cat << EOF | sudo tee /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $(cat /tmp/wg_private.key)
Address = 10.0.255.2/24
MTU = 1420

[Peer]
# RTR-SEDE1 (Casa Central)
PublicKey = PEGAR_AQUI_PUBLIC_KEY_DE_RTR_SEDE1=
Endpoint = 203.0.113.2:51820
AllowedIPs = 10.0.255.0/24, 10.1.0.0/16
PersistentKeepalive = 25
EOF

sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/interface wireguard peers print detail`)

```text
[netops@RTR-SEDE1] > /interface wireguard peers print detail
Flags: X - disabled
 0   ;;; Peer Sucursal 2
     interface=wg-sedes public-key="aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789ABCDEFG="
     current-endpoint-address=181.45.112.88 current-endpoint-port=49122
     allowed-address=10.0.255.2/32,10.2.0.0/16
     rx=148.5MiB tx=212.3MiB last-handshake=42s
```

### En Linux (`sudo wg show`)

```text
interface: wg0
  public key: aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789ABCDEFG=
  private key: (hidden)
  listening port: 51820

peer: xYz9876543210aBcDeFgHiJkLmNoPqRsTuVwXyZ1234=
  endpoint: 203.0.113.2:51820
  allowed ips: 10.0.255.0/24, 10.1.0.0/16
  latest handshake: 42 seconds ago
  transfer: 212.30 MiB received, 148.50 MiB sent
  persistent keepalive: every 25 seconds
```

### Tabla de interpretación de columnas y estados

| Indicador en la salida | Qué significa realmente | Estado sano vs Estado roto |
|------------------------|-------------------------|----------------------------|
| **`last-handshake: 42s`** (`< 3m`) | ✅ **Autenticación criptográfica exitosa:** WireGuard rota las claves de sesión cada 2 minutos (`120s`) mientras hay tráfico | ❌ Si `last-handshake` está **vacío** o nunca aparece, los paquetes `UDP 51820` no están llegando o una de las dos claves públicas fue copiada al revés |
| **`tx=15.2KiB` pero `rx=0B`** (sin `last-handshake`) | Tu router está enviando saludos al `endpoint`, pero **nadie le contesta** | ❌ Revisar que el otro router tenga IP pública real (no CGNAT), que su cadena `INPUT` permita `UDP 51820` y que tenga cargada tu clave pública correcta |
| **`last-handshake: 15s` (`rx` y `tx` suben), hacen ping a `10.0.255.2`, pero NO llegan a la LAN `10.2.10.50`** | El túnel en sí está 100% sano, pero el paquete hacia la LAN muere al querer cruzar | ❌ **3 causas posibles:** 1) Te olvidaste de incluir `10.2.0.0/16` en `allowed-address`, 2) Te olvidaste de crear la ruta en `/ip route`, o 3) El firewall `forward` o una regla de `masquerade` mal hecha lo está pisando |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Querés correr **OSPF** por encima del túnel WireGuard entre Casa Central y la Sucursal, pero la vecindad OSPF no levanta

1. **Causa raíz:** OSPF envía paquetes Multicast a **`224.0.0.5`**.
2. **Qué necesitás agregar en `allowed-address` del Peer WireGuard:**
   - Como WireGuard filtra estrictamente todo paquete cuya IP no esté en `allowed-address`, si vas a correr un protocolo de enrutamiento dinámico (OSPF / RIP / BGP) por adentro del túnel WireGuard, en `allowed-address` debés permitir **`0.0.0.0/0`** (dedicando una interfaz `wg-sede2` punto a punto para esa sucursal) o agregar explícitamente **`224.0.0.0/4`** a la lista `allowed-address`!

### Síntoma 2: Tenés dos sucursales (`Sede 2` y `Sede 3`) en la misma interfaz `wg-sedes` y pusiste `allowed-address=0.0.0.0/0` en ambos peers; ahora ninguna de las dos funciona

1. **Causa raíz (Solapamiento de `AllowedIPs` dentro de la misma interfaz WireGuard):**
   - Recordá que dentro de una misma interfaz `wg-sedes`, WireGuard usa `allowed-address` para decidir **a qué peer mandarle el paquete**.
   - Si en la misma interfaz `wg-sedes` le ponés `0.0.0.0/0` a dos peers distintos, WireGuard solo le mandará todo el tráfico al último peer y dejará al primero sin nada.
2. **Regla inquebrantable:**
   - Si varios peers comparten una misma interfaz `wg-sedes` (Multipunto), **sus `allowed-address` jamás deben solaparse** (Peer 2 lleva `10.0.255.2/32,10.2.0.0/16`; Peer 3 lleva `10.0.255.3/32,10.3.0.0/16`).
   - Si necesitás poner `allowed-address=0.0.0.0/0` para correr OSPF sobre los túneles, creá **una interfaz WireGuard separada por cada sucursal** (`wg-sede2` en puerto `51820`, `wg-sede3` en puerto `51821`).

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Usar también `PresharedKey` (`preshared-key`) opcional para resistencia post-cuántica:**
  - Además de las claves pública/privada Curve25519, WireGuard permite agregar una clave simétrica adicional (`wg genpsk`) en cada peer. Si la agregás, debés copiar exactamente la misma `preshared-key` en ambos lados del par.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Copiar tu propia `Public Key` en el campo `public-key` de la pestaña `Peers`:**
  - Es el error de principiante número 1:
    - En la pestaña **`WireGuard` (la Interfaz)**: vive **TU** clave pública.
    - En la pestaña **`Peers`**: siempre se pega la clave pública **DEL OTRO EQUIPO REMOTO**.
- **❌ Olvidar que WireGuard requiere NTP sincronizado tras un reinicio eléctrico:** WireGuard incluye una marca de tiempo monotónica (`TAI64N`) dentro del paquete de handshake para impedir ataques de repetición (*Replay Attacks*). Si un router remoto sin pila interna se reinicia con fecha `1970` y el concentrador ya había visto un handshake con fecha `2026`, **el concentrador rechazará el handshake del router remoto hasta que ese router sincronice su reloj NTP**.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar QR o configuración con DNS interno para Roadwarriors en RouterOS v7:** RouterOS v7 incluye los campos `client-address`, `client-dns` y `client-endpoint` dentro del Peer y el comando `/interface wireguard peers show-client-config <id>` que **dibuja el código QR directamente en la terminal SSH o en WinBox** para escanearlo desde la app oficial de WireGuard en el celular o laptop en 3 segundos.

---

## 9. 🔗 Referencias internas

- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — Por qué el MTU de WireGuard es `1420 bytes` y cómo actúa el TCP MSS Clamping (`1380 bytes`)
- [`ospf-single-and-multi-area`](../03-routing-l3/ospf-single-and-multi-area.md) — Cómo correr OSPF por encima de túneles WireGuard para failover automático con enlaces de fibra
- [`ipsec-ikev2-site-to-site`](ipsec-ikev2-site-to-site.md) — Qué usar cuando tenés que conectar contra un equipo Cisco, Fortinet o proveedor bancario que exige el estándar clásico **IPsec IKEv2**
