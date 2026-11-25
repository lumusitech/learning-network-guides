⬅️ [Volver a Guías](../README.md)

# Hardening de SSH y Plano de Gestión (Management Plane) — Guía práctica multi-vendor

**Dominio:** `01-fundamentals`
**Nivel:** 🟡 Intermedio
**Estándares:** `RFC 4253 (SSHv2)`, `RFC 8709 (Ed25519)`, `CIS Benchmarks (Cisco / RouterOS)`
**Concepto base:** [`how-to-think-like-network-engineer`](../../concepts/how-to-think-like-network-engineer.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver versión de SSH, sesiones VTY activas y puertos abiertos en el plano de control
show ip ssh
show users
show control-plane host open-ports

# MikroTik RouterOS v7: Auditar qué servicios del router están encendidos y desde qué IPs se permiten
/ip service print
/tool mac-server print
/user active print

# Linux: Verificar desde afuera qué puertos de administración expone un router o switch
nmap -sT -p 21,22,23,80,443,8291,8728,8729 10.1.99.1
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

Cuando sacás un router o switch de la caja, viene pensado para que sea "fácil de encontrar": suele traer usuario `admin` sin contraseña (o contraseña en etiqueta), servicios inseguros en texto plano encendidos (**Telnet `23`, HTTP `80`, FTP `21`, API `8728`**) y escucha conexiones administrativas **en todas sus interfaces, incluyendo la boca WAN conectada a Internet**. Si conectás un router así a una IP pública, en menos de 90 segundos empieza a recibir miles de ataques automatizados de fuerza bruta.

El **Hardening del Plano de Gestión (*Management Plane*)** blinda las puertas administrativas del propio equipo: apaga todos los protocolos en texto plano, reemplaza el usuario `admin` por cuentas nominales con **claves criptográficas SSH**, restringe qué subredes internas tienen permiso de abrir sesión (`VLAN 99 Management` y `VLAN 20 IT`) y bloquea en la cadena `INPUT` cualquier intento de acceso desde Internet o desde las VLANs de usuarios/invitados.

> **🧠 Recordatorio del modelo mental:** Pensá en el Plano de Gestión como **la puerta de la sala de máquinas del edificio**: que los visitantes tengan permiso de caminar por el pasillo (`FORWARD`) jamás significa que la puerta de la sala de calderas (`INPUT`) pueda quedar sin llave ni abierta hacia la vereda de la calle (`WAN`).

---

## 2. 🗺️ Topología de referencia

En todos los bloques configuraremos este mismo blindaje sobre nuestros equipos:

```text
[Internet / WAN] ---X (BLOQUEADO en INPUT: SSH, WinBox, HTTPS, SNMP, Ping opcional)
                           |
                   +---------------+
                   |  RTR-BORDE    | (IP Gestión: 10.1.99.1/24)
                   +---------------+
                           || Trunk (VLANs 10, 20, 99, 200)
                           v
                   +---------------+
                   |   SW-CORE     | (IP Gestión: 10.1.99.2/24)
                   +---------------+
                     /           \
     VLAN 20 (IT/Admin)         VLAN 10 / 200 (Staff / Invitados)
     10.1.20.0/24               10.1.10.0/24 y 10.1.200.0/23
     ✅ ÚNICA red autorizada    ❌ BLOQUEADOS para entrar por SSH/WinBox
        a entrar a 10.1.99.0/24    (Solo pueden consultar DNS/DHCP)
```

| Parámetro de Seguridad | Valor aplicado en los ejemplos |
|------------------------|--------------------------------|
| **VLAN de Gestión (*Management*)** | `VLAN 99` (`10.1.99.0/24`) |
| **Subredes autorizadas a administrar** | `10.1.20.0/24` (IT) y `10.1.99.0/24` (Saltos entre equipos) |
| **Servicios permitidos** | Solo **SSHv2 (`TCP 22`)** (y **WinBox `TCP 8291`** en MikroTik restringido a la LAN de IT) |
| **Servicios deshabilitados** | `Telnet (23)`, `FTP (21)`, `HTTP (80)`, `API (8728/8729)` |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Salvavidas obligatorio:** Antes de deshabilitar el usuario `admin` o aplicar filtros en VTY/`/ip service`, **abrí una segunda ventana SSH sin cerrar la primera** y activá **Safe Mode (`Ctrl+X`)** o `reload in 10`. Nunca cierres tu sesión actual hasta haber probado que podés iniciar sesión nueva con el nuevo usuario y clave.

### A. MikroTik RouterOS (v7+)

```text
# 1. Crear un usuario administrador propio con clave fuerte y (tras probarlo) deshabilitar 'admin'
/user add name=netops group=full password="CambiarPorPasswordLargoYUnico!2026"
# Importar tu clave pública SSH (subida previamente por SCP) y habilitar strong-crypto:
/ip ssh set strong-crypto=yes always-allow-password-login=no
/user ssh-keys import public-key-file=id_ed25519.pub user=netops
# (Una vez que entraste en otra ventana como 'netops', deshabilitá 'admin'):
/user disable admin

# 2. Apagar todos los servicios innecesarios y restringir SSH/WinBox SOLO a las subredes de IT y Management
/ip service disable telnet,ftp,www,api,api-ssl
/ip service set ssh address=10.1.20.0/24,10.1.99.0/24 port=22
/ip service set winbox address=10.1.20.0/24,10.1.99.0/24 port=8291

# 3. Restringir el acceso por MAC (WinBox por Capa 2 y Neighbor Discovery) SOLO a la lista MGMT
/interface list add name=MGMT
/interface list member add list=MGMT interface=vlan99-mgmt
/interface list member add list=MGMT interface=vlan20-it
/ip neighbor discovery-settings set discover-interface-list=MGMT
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=MGMT
/tool mac-server ping set enabled=no
/tool bandwidth-server set enabled=no

# 4. Blindar la cadena INPUT del Firewall (Defensa en profundidad)
/ip firewall filter add chain=input connection-state=established,related,untracked action=accept comment="1. Permitir establecidas"
/ip firewall filter add chain=input connection-state=invalid action=drop comment="2. Descartar invalidas"
/ip firewall filter add chain=input protocol=icmp action=accept comment="3. Permitir ICMP/Ping"
/ip firewall filter add chain=input in-interface-list=MGMT protocol=tcp dst-port=22,8291 action=accept comment="4. Permitir SSH/WinBox solo desde MGMT"
/ip firewall filter add chain=input in-interface-list=!WAN protocol=udp dst-port=53,67,123 action=accept comment="5. DNS/DHCP/NTP para LANs"
/ip firewall filter add chain=input in-interface-list=!WAN protocol=tcp dst-port=53 action=accept comment="6. DNS TCP para LANs"
/ip firewall filter add chain=input action=drop comment="99. DROP TODO EL RESTO HACIA EL ROUTER"
```

### B. Cisco IOS / Catalyst

```cisco
! 1. Definir hostname y dominio (requisitos obligatorios para generar claves criptográficas SSH)
configure terminal
hostname SW-CORE
ip domain-name empresa.local

! 2. Crear usuario nominal con hash irreversible (Type 9 Scrypt / Type 8 PBKDF2) y cifrar passwords en texto
enable algorithm-type scrypt secret CambiarEnableSecretFuerte!2026
username netops privilege 15 algorithm-type scrypt secret CambiarPasswordFuerte!2026
service password-encryption

! 3. Generar par de claves RSA de 2048/4096 bits y forzar exclusivamente SSH versión 2
crypto key generate rsa modulus 2048
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3

! 4. Apagar servidores HTTP/HTTPS inseguros si no se usan
no ip http server
no ip http secure-server

! 5. Crear ACL que solo permita conectarse por SSH desde la VLAN 20 (IT) y VLAN 99 (Management)
ip access-list standard ACL-MGMT-ONLY
 permit 10.1.20.0 0.0.0.255
 permit 10.1.99.0 0.0.0.255
 deny   any log

! 6. Aplicar la ACL y prohibir Telnet en las terminales virtuales (line vty 0 15)
line vty 0 15
 access-class ACL-MGMT-ONLY in
 transport input ssh
 login local
 exec-timeout 10 0
 logging synchronous
exit

end
write memory
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link)

```text
# En Aruba ProCurve / AOS-S:
configure
crypto key generate ssh rsa bits 2048
ip ssh
no telnet-server
no web-management
ip authorized-managers 10.1.20.0 255.255.255.0 access manager
ip authorized-managers 10.1.99.0 255.255.255.0 access manager
write memory
```

### D. Linux (Servidores de red / Routers FRRouting — `/etc/ssh/sshd_config.d/hardening.conf`)

```bash
# 1. Copiar tu clave pública Ed25519 al servidor antes de desactivar contraseñas
ssh-copy-id -i ~/.ssh/id_ed25519.pub netops@10.1.99.10

# 2. Crear configuración de hardening en sshd y validar sintaxis antes de recargar
cat << 'EOF' | sudo tee /etc/ssh/sshd_config.d/99-netops-hardening.conf
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers netops
ListenAddress 10.1.99.10
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

sudo sshd -t && sudo systemctl reload ssh
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En MikroTik (`/ip service print`)

```text
[netops@RTR-BORDE] > /ip service print
Flags: X - DISABLED, I - INVALID
Columns: NAME, PORT, ADDRESS, CERTIFICATE
#   NAME     PORT  ADDRESS                      CERTIFICATE
0 X telnet     23
1 X ftp        21
2 X www        80
3   ssh        22  10.1.20.0/24,10.1.99.0/24
4 X www-ssl   443                               none
5 X api      8728
6   winbox   8291  10.1.20.0/24,10.1.99.0/24
7 X api-ssl  8729                               none
```

### En Cisco IOS (`show ip ssh` y `show users`)

```text
SW-CORE# show ip ssh
SSH Enabled - version 2.0
Authentication methods:publickey,keyboard-interactive,password
Authentication timeout: 60 secs; Authentication retries: 3

SW-CORE# show users
    Line       User       Host(s)              Idle       Location
*  2 vty 0     netops     idle                 00:00:00   10.1.20.50
```

### Tabla de interpretación de columnas y flags

| Columna / Flag | Fabricante | Qué significa realmente | Estado sano vs Estado roto |
|----------------|------------|-------------------------|----------------------------|
| **`X` (*DISABLED*)** | MikroTik (`/ip service`) | El demonio de ese protocolo está completamente apagado y su puerto cerrado | ✅ Sano: `telnet`, `ftp`, `www`, `api` con flag `X`. ❌ Peligroso: activos sin flag `X` |
| **`ADDRESS: 10.1.20.0/24`** | MikroTik (`/ip service`) | Lista blanca a nivel del propio demonio SSH/WinBox (además del firewall `input`) | ✅ Sano: restringido a subredes de IT/Management. ❌ Peligroso: columna `ADDRESS` vacía (permite `0.0.0.0/0`) |
| **`SSH Enabled - version 2.0`** | Cisco (`show ip ssh`) | El motor SSH acepta solo el protocolo v2 (sin vulnerabilidades de SSHv1) | ❌ Peligroso: `version 1.99` (significa que todavía acepta clientes SSH v1 antiguos e inseguros) |
| **`* 2 vty 0`** | Cisco (`show users`) | El asterisco `*` indica cuál es **tu propia sesión actual**; las demás filas son otros administradores conectados | Si ves una IP desconocida en `Location`, podés expulsarla con `clear line vty <N>` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: En Cisco configuraste `transport input ssh`, pero al conectar desde tu laptop dice `Connection refused`

1. **Verificación rápida:** `show ip ssh`
2. **Qué buscar en la salida:** Dice `SSH Disabled - version 1.99. %Please create RSA keys to enable SSH`.
3. **Causa y corrección:** En Cisco IOS, el servidor SSH **no arranca** si antes no definiste un `hostname` distinto a `Switch`/`Router`, un `ip domain-name` y generaste las claves con `crypto key generate rsa modulus 2048`.

### Síntoma 2: En MikroTik cambiaste de laptop o de IP, y ni siquiera podés entrar por MAC en WinBox

1. **Verificación rápida:** Conectar la laptop a un puerto que pertenezca a la `VLAN 20` o `VLAN 99` (miembros de la lista `MGMT`).
2. **Causa y corrección:** Como configuramos `/tool mac-server mac-winbox set allowed-interface-list=MGMT`, WinBox por MAC solo responde en las interfaces de gestión. Si necesitás entrar por IP desde una nueva subred VPN, agregá esa subred a `/ip service set winbox address=...` y a la regla de la cadena `input`.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Doble candado en MikroTik (Defensa en Profundidad):**
  - Siempre restringí los accesos administrativos en **dos lugares independientes**: en `/ip service set ssh,winbox address=...` **Y** en `/ip firewall filter chain=input`. Si mañana durante una prueba alguien desactiva temporalmente una regla del firewall `input`, el demonio `/ip service` sigue rechazando conexiones desde Internet.
- **Cómo limpiar una sesión VTY colgada en Cisco:**
  - Si se te cayó Internet varias veces y agotaste las líneas VTY disponibles: entrá y ejecutá `show users` para ver el número de línea inactiva (ej. `vty 1` con `Idle 02:15:00`) y cerrala con `clear line vty 1`.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Cambiar el puerto de SSH del `22` al `2222` en la boca WAN creyendo que "eso ya es seguridad":** Los escáneres modernos como Shodan y Masscan barren los 65.535 puertos de todo IPv4 en minutos. Cambiar el puerto solo reduce el ruido en los logs, pero **jamás reemplaza el bloqueo total en la WAN + acceso exclusivo por VPN o lista blanca de IPs + autenticación por clave SSH**.
- **❌ En Cisco, usar `password 7 ...` o `enable password` en vez de `secret`:** El algoritmo `Type 7` de Cisco (`service password-encryption`) es un cifrado Vigenère reversible instantáneamente con cualquier calculadora web. Para contraseñas de usuarios y `enable`, usá siempre la palabra clave **`secret`** (preferiblemente con `algorithm-type scrypt` Type 9).
- **❌ Olvidar desactivar `mac-telnet`, `mac-ping` y `bandwidth-server` hacia el proveedor de Internet en MikroTik:** Si tu proveedor te entrega servicio por un enlace Capa 2 compartido con otros clientes del edificio y dejás `/tool mac-server` abierto en `all`, otros clientes conectados al mismo nodo del ISP pueden ver tu router en su pestaña Neighbors de WinBox e intentar atacarlo por Capa 2.

---

## 8. ✅ Buenas prácticas profesionales

- **Cuentas nominales por administrador (`carlos`, `ana`) en lugar de compartir `admin`:** Permite saber en `/log print` o en el servidor Syslog exactamente quién aplicó cada cambio (o centralizar usuarios con **RADIUS / TACACS+**).
- **Banner legal de acceso restringido:** Configurar `/system note` en MikroTik y `banner login` en Cisco advirtiendo que el equipo es privado y toda actividad es registrada en un servidor Syslog externo.
- **Usar un Bastión / Jump Host o VPN WireGuard administrativa:** En lugar de abrir puertos de gestión de 30 switches a toda la red, solo permití que se conecte a la `VLAN 99` la IP del servidor Bastión o el rango de la VPN de los administradores de red.

---

## 9. 🔗 Referencias internas

- [`serial-console-and-oob-access`](serial-console-and-oob-access.md) — Cómo entrar por cable de consola si cometés un error al cerrar el firewall de gestión
- [`stateful-firewalls-and-zone-segmentation`](../../concepts/stateful-firewalls-and-zone-segmentation.md) — Por qué la protección del propio router va siempre en la cadena `INPUT` y no en `FORWARD`
- [`network-ports-protocols-and-multicast`](../../reference/network-ports-protocols-and-multicast.md) — Lista completa de puertos administrativos (`22`, `23`, `8291`, `8728`, `161`) a auditar
