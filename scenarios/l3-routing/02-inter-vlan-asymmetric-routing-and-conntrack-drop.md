⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Las conexiones entre dos subredes internas se cortan a los 30 segundos por ruta asimétrica y descarte `INVALID` en Conntrack

**Dominio:** `l3-routing`
**Nivel:** 🔴 Avanzado
**Capas OSI afectadas:** `Capa 3 (Routing Asimétrico)` y `Capa 4 (Firewall Stateful Conntrack)`
**Equipos involucrados:** `MikroTik RouterOS`, `Cisco Switch L3`, `Linux Firewall`

---

## 🎯 Problema

En la red corporativa, cuando una PC de la `VLAN 10 (`10.1.10.50`)` se conecta por SSH, RDP o base de datos al servidor `10.1.40.10`, **la conexión se establece al primer segundo, pero exactamente a los 15–30 segundos (o al primer reenvío de ventana TCP) se congela y se corta con `Connection reset / timed out`**. Curiosamente, el `ping` entre ambas IPs funciona sin perder paquetes.

```text
EL TRIÁNGULO ASIMÉTRICO QUE VUELVE LOCO AL FIREWALL STATEFUL:
==================================================================================================
                     +----------------------------------------+
                     |     RTR-FIREWALL (10.1.10.1)           |
                     |  Default GW de la PC (10.1.10.50)      |
                     |  2. La VUELTA (SYN-ACK) NO pasa por acá|
                     |  3. Cuando pasa un ACK suelto -> ¡DROP |
                     |     por estado INVALID en Conntrack!   |
                     +----------------------------------------+
                       ^                                    |
     1. IDA (TCP SYN): |                                    | Redirige hacia el Switch L3
     PC manda a su GW  |                                    v (10.1.10.2)
  [PC: 10.1.10.50/24]--+                           +-----------------------------------+
           ^                                       |     SW-CORE L3 (10.1.10.2 y .40.1)|
           |------ 2. VUELTA (SYN-ACK directo!) ---|  Default GW del Servidor (.40.10) |
               (El Switch L3 tiene pata en VLAN 10 +-----------------------------------+
                y le entrega la respuesta directo                  ^
                a la PC esquivando al Firewall!)                   |
                                                        [Servidor: 10.1.40.10/24]
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7: Mirar si el contador de la regla 'drop invalid' en forward sube con cada corte!
/ip firewall filter print stats where connection-state=invalid
/ip firewall connection print where src-address~"10.1.10.50"

# Linux: Verificar descartes por conntrack invalid y filtro rp_filter (Reverse Path Filtering)
sudo nft list chain inet filter forward
sysctl net.ipv4.conf.all.rp_filter

# Traceroute desde AMBOS extremos (PC -> Servidor y Servidor -> PC) para comparar los saltos:
traceroute -n 10.1.40.10   # Desde la PC (10.1.10.50)
traceroute -n 10.1.10.50   # Desde el Servidor (10.1.40.10)
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# 1. Traceroute de IDA (Desde la PC 10.1.10.50 hacia el Servidor 10.1.40.10 -> 2 saltos!):
 1  10.1.10.1 (RTR-FIREWALL)  0.450 ms
 2  10.1.10.2 (SW-CORE-L3)    0.620 ms
 3  10.1.40.10                0.810 ms

# 2. Traceroute de VUELTA (Desde el Servidor 10.1.40.10 hacia la PC 10.1.10.50 -> 1 solo salto!):
 1  10.1.40.1 (SW-CORE-L3)    0.310 ms
 2  10.1.10.50                0.520 ms   <-- ¡Esquivó a RTR-FIREWALL (10.1.10.1)!

# 3. En RTR-FIREWALL (/ip firewall filter print stats):
;;; FWD-3: Descartar invalidas
2 forward  drop  18450200  34120   <-- ¡Sube sin parar!
```

**Interpretación de la evidencia:**

- **El camino de IDA (`PC → Servidor`) pasa por 2 routers (`RTR-FIREWALL` → `SW-CORE-L3`)**, pero **el camino de VUELTA (`Servidor → PC`) pasa por 1 solo router (`SW-CORE-L3`)**.
- Como `RTR-FIREWALL` solo ve los paquetes en un único sentido (ve el `SYN` de la PC y sus `ACK`, pero **jamás ve el `SYN-ACK` de respuesta del servidor**), para la tabla **Conntrack** del firewall la conexión nunca llegó a `ESTABLISHED`: queda en estado incompleto (`SYN_SENT`) y a los pocos segundos el firewall **mata todos los paquetes siguientes de la PC clasificándolos como `connection-state=invalid`**.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Por qué el `ping` sí funcionaba:** Porque ICMP no tiene ventana de secuencia TCP ni estados `SYN / SYN-ACK / FIN`; el ping de ida pasa como `NEW` en cada segundo y la respuesta vuelve directo por el switch.
- **Causa raíz (Capa 3 + Capa 4 — *Hairpin Routing / Asymmetric Routing*):** Se mezclaron **dos routers dentro de la misma subred `10.1.10.0/24`** (`RTR-FIREWALL` en `.1` y `SW-CORE-L3` en `.2`). Las PCs tienen como Default Gateway al `.1` (Firewall), mientras que los servidores tienen como Default Gateway al Switch L3, el cual también tiene una IP en la VLAN 10 (`.2`) y le habla directo a las PCs en Capa 2 sin devolver el tráfico por el Firewall.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **un edificio con un guardia con planilla en la Puerta Principal (`RTR-FIREWALL`) y una Puerta Lateral sin guardia (`SW-CORE-L3`)**: el visitante entra por la Puerta Principal, pero el empleado que lo atiende sale a responderle por la Puerta Lateral. Para el guardia de la Puerta Principal, nadie contestó nunca el llamado, así que a los 30 segundos tacha el permiso como inválido y le cierra la puerta en la cara.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Ejecutar `traceroute` en ambos sentidos

Siempre que una sesión TCP se corte a los pocos segundos entre dos redes internas, corré `traceroute` desde el cliente al servidor **y desde el servidor al cliente**. Los routers por los que pasa la ida **deben ser exactamente los mismos** por los que pasa la vuelta.

### 2. Confirmar con el log de la regla `drop invalid` en el Firewall

```text
# En MikroTik: Activar log temporal en la regla drop invalid:
/ip firewall filter set [find connection-state=invalid and chain=forward] log=yes log-prefix="ASIMETRIA-INVALID:"
/log print follow where message~"ASIMETRIA-INVALID"
```

- Verás paquetes **`TCP (ACK)`** o **`TCP (PSH,ACK)`** siendo descartados por la regla `invalid`.

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/ip address print
/ip route print
```

### 2. Acción correctiva arquitectónica (Elegir una de las 3 soluciones limpias)

#### Solución A (La Mejor Arquitectura): Usar una Subred de Tránsito `/30` (`10.1.255.0/30`) dedicada entre el Firewall y el Switch L3

Si `SW-CORE-L3` es quien enruta las VLANs internas (`10.1.10.1` y `10.1.40.1`), **`RTR-FIREWALL` NO debe tener una pata dentro de la VLAN 10**.

1. El Default Gateway de todas las PCs de la VLAN 10 pasa a ser la SVI de `SW-CORE-L3` (`10.1.10.1`).
2. El Default Gateway de los servidores de la VLAN 40 es la SVI de `SW-CORE-L3` (`10.1.40.1`).
3. Entre `SW-CORE-L3` y `RTR-FIREWALL` solo existe el enlace `/30` (`10.1.255.0/30`). Así, el tráfico entre VLAN 10 y VLAN 40 es **100% simétrico por el Switch L3**, y el tráfico hacia Internet es **100% simétrico por el Firewall**.

#### Solución B (Si no podés cambiar el Default Gateway `.1` de las PCs hoy mismo): Entregar la ruta hacia `10.1.40.0/24` por DHCP (`Option 121` — Classless Static Route)

```text
# En el Servidor DHCP de la VLAN 10, o agregando la ruta en los hosts,
# o bien quitando la IP 10.1.10.2 de la VLAN 10 del Switch L3 y uniendo Switch L3 <-> Firewall por una VLAN 255 de tránsito
# para que el Switch L3 esté OBLIGADO a devolver los paquetes de vuelta a través del Firewall!
```

#### Solución C (Parche inmediato de emergencia en 10 segundos sin cambiar IPs): Eximir el tráfico LAN-a-LAN del chequeo de Conntrack (`action=notrack` en `raw`)

Si necesitás que la planta siga trabajando ya mismo mientras planificás la ventana para mover la IP a una subred de tránsito `/30`:

```text
# En MikroTik RouterOS: Decirle a Conntrack en la tabla RAW que no rastree estados para el triángulo interno 10.1.10.0/24 -> 10.1.40.0/24:
/ip firewall raw
add chain=prerouting src-address=10.1.10.0/24 dst-address=10.1.40.0/24 action=notrack comment="Evitar drop invalid en ruta asimetrica interna"
```

### 3. Rollback

```text
/ip firewall raw remove [find comment~"ruta asimetrica"]
/ip firewall filter set [find connection-state=invalid and chain=forward] log=no
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `traceroute` de ida y `traceroute` de vuelta recorren exactamente los mismos saltos (simetría de rutas).
- [ ] El contador de la regla `drop invalid` en `forward` deja de crecer.
- [ ] Las sesiones SSH, RDP y SMB entre la VLAN 10 y la VLAN 40 permanecen estables durante horas sin microcortes.
- [ ] **Cómo evitar que vuelva a ocurrir:** **Jamás pongas dos routers distintos compartiendo una misma VLAN de usuarios**; los routers y switches L3 se interconectan entre sí siempre mediante una **VLAN o subred de tránsito `/30` dedicada** donde no vive ninguna PC.

---

## 🔗 Referencias

- [`stateful-firewalls-and-zone-segmentation`](../../concepts/stateful-firewalls-and-zone-segmentation.md) — Por qué Conntrack clasifica como `INVALID` los paquetes `ACK` cuando no vio el `SYN-ACK`
- [`inter-vlan-routing-roas-vs-svi`](../../guides/03-routing-l3/inter-vlan-routing-roas-vs-svi.md) — Diseño correcto de la subred de tránsito `/30` (`10.1.255.0/30`) entre un Switch Capa 3 y el Firewall de borde
