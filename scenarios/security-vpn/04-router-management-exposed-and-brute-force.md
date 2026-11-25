⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Router de borde con CPU alta y logs inundados de ataques de fuerza bruta a SSH/WinBox/Telnet desde Internet

**Dominio:** `security-vpn`
**Nivel:** 🟢 Básico
**Capas OSI afectadas:** `Capa 3/4/7 (Management Plane / Firewall INPUT)`
**Equipos involucrados:** `MikroTik RouterOS v7`, `Cisco IOS`, `Linux`

---

## 🎯 Problema

Al entrar al router principal de una empresa para revisar una lentitud, encontrás que **la ventana de Logs (`/log print` / `show logging`) está corriendo a toda velocidad con miles de líneas rojas por minuto: `login failure for user admin/root/ubnt from 45.x.x.x via ssh / telnet / winbox / api`** y el consumo de CPU del router tiene picos constantes por estar calculando hashes criptográficos de miles de intentos de login desde bots en Internet.

```text
[Miles de Bots en Internet] ===(TCP 21, 22, 23, 80, 443, 8291, 8728)===> (ether1-wan) [RTR-BORDE]
                                                                          - Servicios abiertos a 0.0.0.0/0!
                                                                          - Sin regla final DROP en INPUT!
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7: Ver intentos de login en el log, servicios abiertos, sesiones activas y reglas INPUT
/log print where topics~"account|critical|error"
/ip service print
/user active print
/ip firewall filter print stats where chain=input
/system scheduler print

# Cisco IOS: Ver usuarios conectados, intentos fallidos y puertos abiertos en el plano de control
show users
show control-plane host open-ports
show logging | include LOGIN|SEC_LOGIN
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/ip service print + /log print):
#   NAME     PORT  ADDRESS
0   telnet     23
1   ftp        21
2   www        80
3   ssh        22
6   winbox   8291
7   api      8728

14:10:01 system,error,critical login failure for user root from 185.220.101.45 via ssh
14:10:01 system,error,critical login failure for user admin from 103.145.12.99 via telnet
14:10:02 system,error,critical login failure for user admin from 45.155.205.10 via winbox
```

**Interpretación de la evidencia:**

- **Todos los servicios administrativos (incluyendo `telnet`, `ftp`, `www` y `api` en texto plano!) están habilitados y con la columna `ADDRESS` vacía** (aceptan conexiones desde cualquier IP del mundo `0.0.0.0/0`).
- La cadena `INPUT` del firewall no tiene una regla final `action=drop` (o alguien puso una regla `accept` general arriba).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y qué debemos verificar antes de cerrar las puertas:

1. **Verificar primero si algún atacante ya logró entrar (*Compromise Assessment*):**
   - Antes de cerrar el firewall, revisá en MikroTik: **`/user print`** (¿hay usuarios desconocidos?), **`/system scheduler print`** y **`/system script print`** (¿hay tareas programadas que descarguen scripts con `/tool fetch`?), **`/ip socks print`** (¿activaron un proxy SOCKS para usar tu IP?) y **`/ip firewall nat print`** (¿abrieron puertos?).
2. **Por qué hay que cerrar en DOS capas a la vez (`/ip service` + `Firewall INPUT`):**
   - Para no quedarte afuera vos mismo al cerrar la puerta, primero autorizás tu propia interfaz/subred de gestión (`MGMT` / `LAN`) con **Safe Mode (`Ctrl+X`)** activo y recién entonces cerrás el resto.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **tener la puerta de la bóveda del banco dando directo a la vereda de la calle principal**: miles de ladrones pasan por minuto probando llaves al azar en la cerradura. No tenés que ponerte a anotar el nombre de cada ladrón que pasa por la vereda (listas de bloqueo infinitas); **tenés que tapiar la puerta que da a la vereda (`DROP` en `INPUT` desde `WAN`) y dejar que a la bóveda solo se entre desde el pasillo interno de seguridad (`MGMT / VPN`)**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico y respuesta)

### 1. Auditar en 20 segundos que el equipo no tenga persistencia maliciosa

```text
# En MikroTik RouterOS:
/user print
/system scheduler print
/system script print
/ip socks print
/ip proxy print
```

### 2. Identificar desde qué IP e interfaz estás conectado VOS ahora mismo

```text
# En MikroTik: Mirá tu propia fila en /user active print (tu IP aparece en la columna ADDRESS):
/user active print

# En Cisco IOS: Mirá la fila que tiene el asterisco '*' a la izquierda:
show users
```

> ⚠️ **¡Crítico!** Si estás conectado al router remotamente desde tu casa a través de la IP pública WAN (porque aún no tenías configurada una VPN WireGuard), **asegurate de incluir tu IP pública actual en la lista blanca antes de activar el bloqueo de la WAN!**

---

## 🧯 Mitigación y Rollback

> ⚠️ **Salvavidas obligatorio:** Presioná **`Ctrl+X` (Safe Mode)** en MikroTik o ejecutá **`reload in 10`** en Cisco antes de tocar `/ip service` o la cadena `INPUT`.

### 1. Verificar antes de tocar (Backup rápido)

```text
/export show-sensitive file=pre-cierre-wan
```

### 2. Acción correctiva por fabricante (Doble Candado: Demonios + Firewall `INPUT`)

#### En MikroTik RouterOS v7

```text
# 1. Apagar de inmediato Telnet, FTP, HTTP, API y restringir SSH/WinBox SOLO a tus subredes internas (y VPN):
/ip service
disable telnet,ftp,www,www-ssl,api,api-ssl
set ssh    address=10.1.0.0/16,10.0.255.0/24 port=22
set winbox address=10.1.0.0/16,10.0.255.0/24 port=8291

# 2. Apagar descubrimiento y acceso por MAC hacia la boca WAN:
/ip neighbor discovery-settings set discover-interface-list=!WAN
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=!WAN
/tool bandwidth-server set enabled=no

# 3. Blindar la cadena INPUT del Firewall (Permitiendo establecidas, LANs y WireGuard, y bloqueando la WAN):
/ip firewall filter
add chain=input connection-state=established,related,untracked action=accept comment="IN-1: Aceptar establecidas"
add chain=input connection-state=invalid action=drop comment="IN-2: Descartar invalidas"
add chain=input protocol=icmp action=accept comment="IN-3: Permitir ICMP"
add chain=input in-interface-list=!WAN protocol=tcp dst-port=22,8291 action=accept comment="IN-4: SSH/WinBox desde LAN/VPN"
add chain=input in-interface-list=!WAN protocol=udp dst-port=53,67,123 action=accept comment="IN-5: DNS/DHCP/NTP para LAN"
add chain=input in-interface-list=!WAN protocol=tcp dst-port=53 action=accept comment="IN-6: DNS TCP para LAN"
add chain=input action=drop comment="IN-99: BLOQUEAR TODO ACCESO DESDE WAN AL ROUTER"

# 4. Cambiar contraseñas y deshabilitar el usuario 'admin' por defecto (una vez creado tu usuario nominal):
/user add name=netops group=full password="NuevoPasswordInquebrantable!2026"
# (Entrar en otra ventana con 'netops' y desactivar 'admin'):
/user disable admin
```

#### En Cisco IOS / Catalyst

```cisco
configure terminal
no ip http server
no ip http secure-server

ip access-list standard ACL-VTY-SEGURA
 permit 10.1.0.0 0.0.255.255
 permit 10.0.255.0 0.0.0.255
 deny   any log
exit

line vty 0 15
 access-class ACL-VTY-SEGURA in
 transport input ssh
 login local
exit
end
write memory
```

### 3. Rollback

- Si te habías olvidado de incluir tu propia subred y perdiste conexión, **Safe Mode (`Ctrl+X`)** o `reload in 10` revertirá el cambio solo sin que tengas que viajar al sitio.

---

## ✅ Verificación post-incidente y Prevención

- [ ] Los mensajes `login failure ... via ssh/telnet/winbox` en `/log print` **se detienen por completo en el acto (0 por hora)**.
- [ ] Desde una conexión externa (4G / VPS), `nmap -Pn -p 21,22,23,80,443,8291,8728 <IP_PUBLICA>` muestra todos los puertos como **`filtered`** (`DROP` silencioso).
- [ ] **Cómo evitar que vuelva a ocurrir:** Jamás conectar un router nuevo a Internet sin aplicar primero la plantilla de [`routeros-v7-first-setup-and-hardening.md`](../../guides/06-mikrotik/routeros-v7-first-setup-and-hardening.md), y realizar toda administración remota exclusivamente entrando primero por un túnel **WireGuard (`UDP 51820`)**.

---

## 🔗 Referencias

- [`ssh-hardening-and-management-plane`](../../guides/01-fundamentals/ssh-hardening-and-management-plane.md) — Guía completa multi-vendor de blindaje del plano de gestión
- [`routeros-v7-first-setup-and-hardening`](../../guides/06-mikrotik/routeros-v7-first-setup-and-hardening.md) — Plantilla maestra de inicialización segura en MikroTik RouterOS v7
- [`wireguard-site-to-site-and-roadwarrior`](../../guides/04-firewalls-nat-vpn/wireguard-site-to-site-and-roadwarrior.md) — Cómo configurar acceso Roadwarrior por WireGuard para nunca exponer SSH ni WinBox a Internet
