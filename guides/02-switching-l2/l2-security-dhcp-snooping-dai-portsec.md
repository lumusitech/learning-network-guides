⬅️ [Volver a Guías](../README.md)

# Seguridad en Capa 2: DHCP Snooping, Dynamic ARP Inspection (DAI) y Port Security — Guía práctica multi-vendor

**Dominio:** `02-switching-l2`
**Nivel:** 🔴 Avanzado
**Estándares:** `RFC 3046 (DHCP Option 82)`, `DHCP Snooping`, `DAI (Dynamic ARP Inspection)`, `MAC Limiting`
**Concepto base:** [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md)

---

## ⚡ Quick verification (Comandos de diagnóstico rápido)

```text
# Cisco IOS: Ver estado de DHCP Snooping, tabla de bindings (MAC <-> IP <-> Puerto), DAI y Port Security
show ip dhcp snooping
show ip dhcp snooping binding
show ip arp inspection
show port-security interface Gi1/0/2

# MikroTik RouterOS v7: Verificar DHCP Snooping en el bridge y qué puertos son Trusted vs Untrusted
/interface bridge print
/interface bridge port print detail where trusted=yes

# Aruba / HP ProCurve: Ver estado de DHCP Snooping, puertos Trusted y base de bindings
show dhcp-snooping
show dhcp-snooping binding
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

Un firewall de borde te protege de los atacantes que vienen desde Internet, pero **no ve nada de lo que pasa adentro de un switch en Capa 2**. Sin seguridad en Capa 2, cualquier empleado o visitante que enchufe algo en una roseta de pared puede provocar tres desastres:

1. **Rogue DHCP Server (El accidente más común en oficinas):** Alguien conecta un router WiFi hogareño por una de sus bocas LAN a la pared y empieza a repartir IPs falsas (`192.168.0.x`), dejando sin red a toda la planta. **Lo frena: *DHCP Snooping*.**
2. **ARP Spoofing / Man-in-the-Middle:** Un atacante en la VLAN 10 envía respuestas ARP falsas diciendo *"Yo soy la IP `10.1.10.1` (el Gateway)"* para interceptar todo el tráfico de sus compañeros. **Lo frena: *Dynamic ARP Inspection (DAI)*.**
3. **Agotamiento de Tabla CAM (*MAC Flooding*) o conexión de switches no autorizados:** Un equipo inyecta miles de MACs falsas por segundo para llenar la memoria del switch o enchufan un switch de 16 bocas en un escritorio donde solo debía haber 1 PC. **Lo frena: *Port Security*.**

> **🧠 Recordatorio del modelo mental:** Pensá en **DHCP Snooping** como dividir las puertas del edificio en **Mostrador Oficial (`Trusted` — donde está tu Router)** y **Pasillos del Público (`Untrusted` — todas las bocas de escritorios)**: todo el mundo puede *pedir* una credencial (`DHCP Discover`), pero **solo quien está sentado detrás del Mostrador Oficial (`Trusted`) tiene permiso para *entregar* credenciales (`DHCP Offer / ACK`)**. Y mientras las entrega, el guardia anota en un libro oficial (`DHCP Snooping Binding Table`) qué DNI (`MAC`) recibió qué número (`IP`) en qué silla (`Puerto`), libro que luego usa **DAI** para arrestar a cualquiera que mienta en un paquete ARP.

---

## 2. 🗺️ Topología de referencia

Configuraremos el switch `SW-ACCESO` para que **únicamente el Puerto 1 (que sube al Router legítimo)** sea `Trusted`, mientras que todas las bocas de oficina (`Puertos 2 al 24`) sean `Untrusted` con límite de MACs:

```text
               [RTR-BORDE: Servidor DHCP Oficial 10.1.10.1]
                                   ||
                                   || ✅ PUERTO 1: TRUSTED (Único autorizado a enviar DHCP Offer/ACK!)
                                   v
         +----------------------------------------------------+
         |                     SW-ACCESO                      |
         |  - DHCP Snooping = ON (VLANs 10, 100, 200)         |
         |  - Tabla Binding: MAC <-> IP <-> VLAN <-> Puerto   |
         |  - Dynamic ARP Inspection (DAI) = ON               |
         +----------------------------------------------------+
                |                                      |
   ⚠️ PUERTO 2: UNTRUSTED                 ⚠️ PUERTO 3: UNTRUSTED
   (Max 2 MACs, Rate Limit 15 pps)        (Si alguien enchufa un router
                |                          TP-Link acá, el switch BLOQUEA
                v                          sus DHCP Offer en el acto!)
       [PC Legítima: 10.1.10.105]                      |
                                                       v
                                          [❌ Rogue DHCP Intruso Bloqueado]
```

| Función de Seguridad | En Puerto 1 (Uplink hacia Router/Servidor DHCP) | En Puertos 2–24 (Bocas de Usuarios / Cámaras) |
|----------------------|-------------------------------------------------|-----------------------------------------------|
| **DHCP Snooping** | **`trusted = yes`** (`ip dhcp snooping trust`) | **`trusted = no`** (`untrusted` por defecto + límite `15 pps`) |
| **Dynamic ARP Inspection (DAI)** | **`ip arp inspection trust`** | **Valida cada paquete ARP** contra la tabla de DHCP Snooping |
| **Port Security (Límite de MACs)** | Desactivado (por un Trunk pasan cientos de MACs!) | **Máximo `2` o `3` MACs** por boca (PC + Teléfono IP) |

---

## 3. 🛠️ Configuración paso a paso por fabricante

> ⚠️ **Regla de Oro para no dejar sin DHCP a toda la empresa:**
> Cuando encendés **DHCP Snooping**, por defecto **TODOS los puertos del switch pasan a ser `Untrusted`** (bloquean las respuestas del servidor DHCP). **NUNCA olvides marcar como `Trusted` el puerto Trunk (`Puerto 1`) que sube hacia tu Router o Servidor DHCP** (y los Trunks intermedios entre switches).

### A. Cisco IOS / Catalyst (El combo completo: `DHCP Snooping` + `DAI` + `Port Security`)

```cisco
configure terminal

! 1. ENCENDER DHCP SNOOPING en las VLANs de usuarios (y desactivar Option 82 si el router no la espera)
ip dhcp snooping
ip dhcp snooping vlan 10,100,200
no ip dhcp snooping information option

! 2. ENCENDER DYNAMIC ARP INSPECTION (DAI) apoyado en la base de datos de DHCP Snooping
ip arp inspection vlan 10,100,200
ip arp inspection validate src-mac ip

!    *(Importante: Si en la VLAN 10 tenés una impresora con IP FIJA manual que no usa DHCP,
!      creá una entrada estática ARP ACL para que DAI no la bloquee)*:
arp access-list ACL-IPS-FIJAS
 permit ip host 10.1.10.200 mac host 0017.c8aa.1122
exit
ip arp inspection filter ACL-IPS-FIJAS vlan 10

! 3. EN EL PUERTO 1 (TRUNK HACIA EL ROUTER): Marcar como TRUSTED para DHCP y para ARP!
interface GigabitEthernet1/0/1
 description UPLINK_RTR_BORDE_TRUSTED
 ip dhcp snooping trust
 ip arp inspection trust
exit

! 4. EN LOS PUERTOS DE USUARIOS (2 al 24): Untrusted + Rate Limit + Port Security (máx 2 MACs)
interface range GigabitEthernet1/0/2 - 24
 ! Limitar paquetes DHCP y ARP a 15 por segundo para frenar ataques de agotamiento
 ip dhcp snooping limit rate 15
 ip arp inspection limit rate 15
 ! Activar Port Security: máximo 2 MACs (ej. Teléfono IP + PC), acción 'restrict' (descarta y loguea sin apagar toda la boca)
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation restrict
 switchport port-security aging time 5
 switchport port-security aging type inactivity
exit

end
write memory
```

### B. MikroTik RouterOS v7 (`Bridge DHCP Snooping` + `Port Trusted` + `MAC Learning Limit`)

```text
# 1. PRIMERO: Marcar como 'trusted=yes' el puerto Trunk (ether1 o bond1) que sube hacia el Router DHCP!
/interface bridge port
set [find interface=ether1] trusted=yes

# 2. Asegurar que todos los puertos de acceso a usuarios (ether2..ether24) sean 'trusted=no'
set [find interface~"ether([2-9]|1[0-9]|2[0-4])"] trusted=no

# 3. AHORA SÍ: Encender DHCP Snooping en el bridge1
#    (Si tu servidor DHCP no usa Option 82, dejá add-dhcp-option82=no)
/interface bridge
set bridge1 dhcp-snooping=yes add-dhcp-option82=no

# 4. (En switches CRS3xx) Limitar o fijar aprendizaje de MACs / Aislamiento de puertos entre invitados:
#    Para que dos puertos de la VLAN Invitados no puedan hablar directo entre sí en Capa 2 (Port Isolation):
#    /interface bridge port set [find pvid=200] horizon=1
```

### C. Switches Gestionables (Aruba / Ubiquiti / TP-Link)

```text
# En Aruba ProCurve / AOS-S:
configure

# 1. Activar DHCP Snooping y ARP Protection en las VLANs 10, 100 y 200
dhcp-snooping
dhcp-snooping vlan 10 100 200
no dhcp-snooping option 82
arp-protect
arp-protect vlan 10 100 200

# 2. Marcar el Puerto 1 (Trunk al Router) como Trusted para DHCP y ARP
dhcp-snooping trust 1
arp-protect trust 1

# 3. Limitar a 2 direcciones MAC los puertos de acceso (2 al 24)
port-security 2-24 learn-mode limited-continuous address-limit 2 action send-alarm

write memory
```

---

## 4. 🔑 Salida clave e interpretación de flags

### En Cisco IOS (`show ip dhcp snooping binding` y logs de bloqueo)

```text
SW-ACCESO# show ip dhcp snooping binding
MacAddress          IpAddress        Lease(sec)  Type           VLAN  Interface
------------------  ---------------  ----------  -------------  ----  --------------------
AA:BB:CC:00:11:50   10.1.10.105      28450       dhcp-snooping   10    GigabitEthernet1/0/2
9C:EB:E8:12:34:56   10.1.100.50      27900       dhcp-snooping   100   GigabitEthernet1/0/3

! Cuando alguien enchufa un router TP-Link pirata en el puerto 3 o intenta ARP Spoofing:
%DHCP_SNOOPING-4-DHCP_SNOOPING_UNTRUSTED_PORT: DHCP_SNOOPING drop message on untrusted port Gi1/0/3, message type: DHCPOFFER, MAC sa: 50c7.bfaa.bbcc
%SW_DAI-4-DHCP_SNOOPING_DENY: 1 Invalid ARPs (Req) on Gi1/0/2, vlan 10.([aabb.cc00.1150/10.1.10.1/0000.0000.0000/10.1.10.55])
```

### En MikroTik (`/interface bridge port print detail`)

```text
[netops@SW-ACCESO] > /interface bridge port print where interface~"ether[1-3]"
Flags: H - HW-OFFLOAD
Columns: INTERFACE, BRIDGE, HW, PVID, TRUSTED
#   INTERFACE  BRIDGE   HW   PVID  TRUSTED
0 H ether1     bridge1  yes     1  yes
1 H ether2     bridge1  yes    10  no
2 H ether3     bridge1  yes   100  no
```

### Tabla de interpretación de columnas y alertas

| Salida / Alerta | Fabricante | Qué significa realmente | Acción operativa |
|-----------------|------------|-------------------------|------------------|
| **`drop message on untrusted port ... DHCPOFFER`** | Cisco / Aruba / MikroTik | ✅ **¡Salvada exitosa!** Un equipo conectado en una boca de usuario intentó repartir IPs y el switch destruyó su `DHCPOFFER` en la puerta | Ir al puerto indicado (`Gi1/0/3`) y retirar el router doméstico mal conectado |
| **`%SW_DAI-4-DHCP_SNOOPING_DENY: Invalid ARPs`** | Cisco / Aruba | Un equipo en ese puerto intentó anunciar por ARP una dirección IP que **no es la que le entregó el servidor DHCP oficial** | Si es una PC de usuario: posible ataque de *ARP Spoofing* o alguien se puso una IP fija manual sin permiso |
| **`TRUSTED: yes` vs `no`** | Todos | `yes`: se aceptan paquetes de servidor DHCP (`Offer/ACK`, origen `UDP 67`). `no`: solo se aceptan pedidos de cliente (`Discover/Request`, origen `UDP 68`) | Solo los uplinks hacia el servidor DHCP (y trunks entre switches que llevan hacia él) deben ser `TRUSTED: yes` |

---

## 5. 🔍 Uso en troubleshooting

### Síntoma 1: Activaste `ip dhcp snooping` en un switch Cisco, pusiste `ip dhcp snooping trust` en el uplink, pero aun así las PCs dejan de recibir IP del router MikroTik/Linux

1. **Causa raíz (La trampa de la `Option 82` en Cisco):**
   - Por defecto, cuando activás `ip dhcp snooping` en un switch Cisco, el switch **le inyecta la `DHCP Option 82` (*Relay Agent Information*)** al paquete `DHCP Discover` pero deja el campo **`GIADDR = 0.0.0.0`**.
   - Por estándar RFC, muchos servidores DHCP (incluyendo configuraciones por defecto de ISC-DHCP y RouterOS) ven un paquete con `Option 82` pero con `GIADDR = 0.0.0.0` y **lo descartan por considerarlo inválido**.
2. **Corrección inmediata en el switch Cisco:**
   - Ejecutá en modo global: **`no ip dhcp snooping information option`** (o en Aruba: `no dhcp-snooping option 82`). Instantáneamente todas las PCs reciben su IP.

### Síntoma 2: Hay dos switches en cascada (`Router ↔ Switch 1 ↔ Switch 2`): las PCs del Switch 1 reciben IP pero las del Switch 2 no

1. **Causa raíz:** En el `Switch 1`, marcaste como `trusted` el puerto que sube al `Router`, y en el `Switch 2` marcaste como `trusted` el puerto que sube al `Switch 1`.
2. **¿Por qué podría fallar si además activaste `Option 82` o tenés un AP con controlador?** Si en el `Switch 2` hay otro servidor legítimo o si activaste DAI entre ambos switches, recordá que en el `Switch 1` el puerto Trunk que baja hacia el `Switch 2` debe tener `ip arp inspection trust` para no descartar respuestas ARP de equipos estáticos del Switch 2.

---

## 6. 🛡️ Mantenimiento, backup y rollback seguro

- **Guardar la base de datos de DHCP Snooping en memoria Flash:**
  - Si un switch con **DAI (Dynamic ARP Inspection)** se reinicia por un corte de luz, al volver a encenderse **su tabla de DHCP Snooping en RAM está vacía**. Entonces las PCs (que todavía tienen su IP válida por otras 4 horas y no vuelven a pedir DHCP al instante) intentan hablar por ARP y **DAI las bloquea porque no figuran en la tabla vacía**.
  - **Solución profesional en Cisco/Aruba:** Guardar la tabla de bindings automáticamente en un archivo de la memoria flash: `ip dhcp snooping database flash:dhcp-snooping.db`. Así, si el switch se reinicia, recarga las concesiones vigentes en 1 segundo.

---

## 7. ⚠️ Errores comunes en producción

- **❌ Activar `Port Security` con `maximum 2` en un puerto donde va conectado un Access Point WiFi o un servidor de virtualización (Proxmox/VMware):** Por el cable de un Access Point WiFi o de un servidor con 20 máquinas virtuales entran decenas de direcciones MAC distintas. Si le ponés `maximum 2`, apenas se conecte el tercer celular al WiFi el switch **bloqueará el puerto del Access Point entero**. `Port Security` con límite bajo solo se aplica en rosetas de escritorios para PCs/Teléfonos.
- **❌ En Cisco Port Security, dejar el modo de violación por defecto (`violation shutdown`) en oficinas donde la gente cambia de laptop constantemente:** Si el límite es `1` y un empleado desconecta su laptop y enchufa otra antes de que venza el timer de inactividad, `violation shutdown` apaga la boca (`err-disabled`) y genera un ticket de soporte. Usar **`violation restrict`** más **`aging time 5` + `aging type inactivity`** bloquea solo la MAC excedente mientras haya 2 activas a la vez, y libera el lugar solo a los 5 minutos de desenchufar la laptop anterior.

---

## 8. ✅ Buenas prácticas profesionales

- **Usar `horizon=1` (*Port Isolation* / *Protected Ports*) en puertos de WiFi Invitados o habitaciones de hotel:** En MikroTik, si ponés `horizon=1` en todos los puertos de una VLAN de invitados (en Cisco: `switchport protected`), ningún puerto con `horizon=1` puede enviar tramas de Capa 2 a otro puerto con el mismo `horizon=1`, obligando a que solo puedan hablar hacia el gateway y nunca escanear a la habitación de al lado.

---

## 9. 🔗 Referencias internas

- [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md) — Cómo funciona el ciclo DORA y cómo se infiltra un *Rogue DHCP*
- [`ethernet-mac-and-arp`](../../concepts/ethernet-mac-and-arp.md) — Cómo funciona el protocolo ARP y por qué es vulnerable a *ARP Spoofing* si no se usa DAI
- [`vlans-8021q-access-trunk-pvid`](vlans-8021q-access-trunk-pvid.md) — Configuración base de los puertos Access y Trunk sobre los que se aplica DHCP Snooping
