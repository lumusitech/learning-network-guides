⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: El WiFi conecta pero el celular queda en "Obteniendo dirección IP..." (`169.254.x.x`) por VLAN faltante en el puerto del Switch

**Dominio:** `wireless`
**Nivel:** 🟢 Básico
**Capas OSI afectadas:** `Capa 2 (IEEE 802.1Q Trunk hacia el AP)` y `Capa 7 (DHCP)`
**Equipos involucrados:** `Ubiquiti UniFi / MikroTik AP`, `Switch Cisco / MikroTik / Aruba`, `Router DHCP`

---

## 🎯 Problema

Se crea una nueva red WiFi **`"Empresa-Invitados"`** asociada a la **`VLAN 200`** en el controlador WiFi (o se instala un nuevo Access Point en la Sala de Capacitación). Los usuarios ven el nombre del WiFi, ingresan la contraseña, **el celular valida la contraseña al instante, pero se queda 30 segundos diciendo *"Obteniendo dirección IP..."* y termina con el cartel *"Sin conexión a Internet"* (o IP `169.254.x.x`)**. Mientras tanto, en ese mismo AP o en las PCs por cable la red funciona normal.

```text
[Celular] ===(Conecta WPA2 OK!)===> [Access Point: Pone Tag VLAN 200] ===(Cable UTP)===> [SW-ACCESO: Puerto 4]
                                                                                          PVID = 99 (Mgmt AP OK)
                                                                                          Tagged = 10 (Staff OK)
                                                                                          ❌ ¡FALTA Tagged = 200!
                                                                                          (El DHCP Discover muere
                                                                                           en la boca 4 del switch!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# 1. En el Switch donde está conectado el Access Point (Puerto 4): Verificar qué VLANs están permitidas!
# Cisco IOS:
show interfaces Gi1/0/4 switchport | include Mode|Native|Trunking VLANS
show interfaces trunk

# MikroTik RouterOS v7 (Switch):
/interface bridge vlan print where vlan-ids=200

# Aruba / HP ProCurve:
show vlans ports 4 detail

# 2. En el Router Principal (Servidor DHCP de la VLAN 200): Ver si llega algún paquete DHCP Discover!
/tool sniffer quick interface=vlan200-guest ip-protocol=udp port=67,68
/ip dhcp-server print
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En el Switch Cisco donde está enchufado el AP (show interfaces trunk):
Port        Mode             Encapsulation  Status        Native vlan
Gi1/0/1     on               802.1q         trunking      999
Gi1/0/4     on               802.1q         trunking      99

Port        Vlans allowed on trunk
Gi1/0/1     10,99,100,200
Gi1/0/4     10,99             <-- ¡En el puerto 4 del AP solo estaban permitidas 10 y 99! (Falta la 200!)
```

**Interpretación de la evidencia:**

- En el enlace Trunk principal hacia el Router (`Gi1/0/1`) la `VLAN 200` sí está permitida (`10,99,100,200`).
- Pero en el puerto **`Gi1/0/4` (donde está enchufado el Access Point)** solo estaban permitidas las VLANs `10` y `99`. Cuando el AP le estampa la etiqueta **`VLAN 200`** al pedido `DHCP Discover` del celular y lo manda por el cable hacia `Gi1/0/4`, el switch lo descarta en la puerta.

---

## 🧠 Diagnóstico por capas

Por qué este síntoma es tan fácil de diagnosticar si separás Capa 2 WiFi de Capa 2 Ethernet:

- **Si la contraseña WiFi es rechazada:** El problema está en el AP o en RADIUS.
- **Si acepta la contraseña WiFi pero se queda en *"Obteniendo dirección IP..."* (`169.254.x.x`):** El WiFi ya cumplió su trabajo! El problema es **100% que el paquete `DHCP Discover` etiquetado en esa VLAN no está llegando desde el AP hasta el Servidor DHCP** (o el pool DHCP se llenó).

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **el recepcionista del Access Point que le pega al visitante el sticker verde (`VLAN 200`) y lo manda por el pasillo #4 hacia la oficina de acreditaciones (el Router DHCP), pero el guardia del pasillo #4 del switch tiene una lista vieja donde solo figuran los stickers `10` y `99`, así que no lo deja pasar**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Seguir la cadena completa de Trunks de la `VLAN 200` desde el AP hasta el Router

Para que el celular en la `VLAN 200` reciba IP, la `VLAN 200` tiene que estar dada de alta en **estos 4 eslabones**:

```text
[Eslabón 1: SSID en el AP]        --> ¿Tiene asignado VLAN ID = 200?
        |
        v
[Eslabón 2: Puerto del Switch del AP] --> ¿Tiene la VLAN 200 como TAGGED (allowed vlan)?
        |
        v
[Eslabón 3: Puerto Uplink del Switch] --> ¿Existe la VLAN 200 en el switch y sube TAGGED al Router?
        |
        v
[Eslabón 4: Router DHCP]          --> ¿Existe la subinterfaz vlan200 con IP y DHCP Server activo (y pool con IPs libres)?
```

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
show running-config interface Gi1/0/4
/interface bridge vlan print
```

### 2. Acción correctiva por fabricante (Permitir la `VLAN 200` como `Tagged` en el puerto del AP y en todos los Trunks)

#### En Switch Cisco IOS

```cisco
configure terminal
! 1. Asegurar que la VLAN 200 exista en la base de datos Capa 2 del switch:
vlan 200
 name WIFI_GUEST
exit

! 2. Agregar la VLAN 200 al puerto del AP (¡USANDO 'add' para no borrar las VLANs 10 y 99!):
interface GigabitEthernet1/0/4
 switchport trunk allowed vlan add 200
exit
end
write memory
```

#### En Switch MikroTik RouterOS v7

```text
# Agregar el puerto del AP (ether4) a la lista 'tagged=' de la VLAN 200 en el bridge:
/interface bridge vlan
set [find vlan-ids=200] tagged=ether1,ether4
```

#### En Switch Aruba / HP ProCurve

```text
configure
vlan 200
   name "WIFI_GUEST"
   tagged 1,4
   exit
write memory
```

### 3. Rollback

```text
# Cisco:    interface Gi1/0/4 -> switchport trunk allowed vlan remove 200
# MikroTik: /interface bridge vlan set [find vlan-ids=200] tagged=ether1
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] Al reconectar el celular al WiFi `"Empresa-Invitados"`, obtiene dirección IP (`10.1.200.x/23`) en **menos de 2 segundos**.
- [ ] En el router, `/ip dhcp-server lease print where server=dhcp-vlan200` muestra el lease en estado **`bound`**.
- [ ] **Cómo evitar que vuelva a ocurrir:** Si tu red de invitados recibe cientos de celulares por día, usar una subred **`/23` (`510 IPs`)** con un **`lease-time` corto (`1h` o `2h`)** para que nunca se agote el pool DHCP, y estandarizar una plantilla de puerto para todos los APs del edificio (`Port Profile: AP-Trunk`).

---

## 🔗 Referencias

- [`vlans-8021q-access-trunk-pvid`](../../guides/02-switching-l2/vlans-8021q-access-trunk-pvid.md) — Configuración del Puerto 4 (Híbrido) para Access Points
- [`enterprise-wifi-vlans-and-roaming`](../../guides/05-wireless-poe/enterprise-wifi-vlans-and-roaming.md) — Guía completa de mapeo SSID ↔ VLAN
- [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md) — Por qué una falla en el ciclo DORA termina en dirección APIPA `169.254.x.x`
