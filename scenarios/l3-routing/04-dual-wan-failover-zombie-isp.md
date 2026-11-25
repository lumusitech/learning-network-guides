⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: El proveedor de Internet principal se queda sin tráfico pero el failover no salta al ISP secundario ("El ISP Zombie")

**Dominio:** `l3-routing`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 3 (Recursive Routing / IP SLA Failover)`
**Equipos involucrados:** `MikroTik RouterOS v7`, `Cisco IOS`, `Dual-WAN`

---

## 🎯 Problema

La empresa paga dos proveedores de Internet (`WAN 1 Fibra Principal` y `WAN 2 Cable/Starlink Backup`). Hoy a las 10:00 AM se cayó el nodo zonal del Proveedor 1 y toda la oficina se quedó sin Internet. Cuando revisás el router, ves que **la ruta hacia el Proveedor 1 sigue figurando Activa (`As`) porque el módem del Proveedor 1 dentro del rack sigue encendido y respondiendo al ping en `192.168.1.1`**, por lo que el router jamás conmutó al Proveedor 2.

```text
[ISP 1: NODO CAÍDO EN LA CALLE!] ---X--- [Módem ISP 1 en el Rack: 192.168.1.1]
                                                    |
                                                    | (¡El cable Ethernet está UP y 192.168.1.1
                                                    |  responde al ping! El router cree que hay Internet!)
                                                    v
                                         +---------------------+
                                         |      RTR-BORDE      | ===> [ISP 2 Backup: 100% Sano pero sin usar!]
                                         +---------------------+
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7: Ver qué dirección IP está chequeando la ruta por defecto 0.0.0.0/0
/ip route print detail where dst-address=0.0.0.0/0
/ping 1.1.1.1 interface=ether1-wan1 count=3

# Cisco IOS: Ver estado de la ruta 0.0.0.0 y si tiene un objeto Track / IP SLA asociado
show ip route 0.0.0.0
show track
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/ip route print detail where dst-address=0.0.0.0/0):
 0  As   dst-address=0.0.0.0/0 gateway=192.168.1.1 immediate-gw=192.168.1.1%ether1-wan1
         check-gateway=ping distance=1 scope=30 target-scope=10

 1   s   dst-address=0.0.0.0/0 gateway=198.51.100.1 immediate-gw=198.51.100.1%ether2-wan2
         check-gateway=ping distance=2 scope=30 target-scope=10
```

**Interpretación de la evidencia:**

- La ruta 0 tiene `check-gateway=ping`, pero su `gateway` es **`192.168.1.1` (la IP LAN privada de la caja plástica del módem del ISP 1 que está a 30 centímetros de tu router)**.
- Como el módem del ISP 1 está enchufado a la corriente, `192.168.1.1` responde al ping en `0.3 ms` aunque el cable de fibra óptica de la vereda esté cortado por una excavadora.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (El ISP 2 de backup también está caído):** Si hacés ping saliendo por `ether2-wan2` (`/ping 8.8.8.8 interface=ether2-wan2`), responde perfecto.
- **Causa raíz (Capa 3 — Chequeo de primer salto en vez de chequeo recursivo a Internet):** Vigilar la IP del módem solo detecta si se quema la fuente del módem o si alguien desenchufa el patchcord `ether1`. Para detectar un corte real de proveedor (**ISP Zombie**), la ruta por defecto debe resolverse de forma **Recursiva** contra un servidor externo en Internet (`1.1.1.1` o `8.8.8.8`).

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **preguntarle al portero de tu propio edificio si el aeropuerto está abierto**: el portero te contesta *"¡Sí, yo estoy acá despierto!"*, pero la autopista hacia el aeropuerto está cortada a 2 kilómetros. Tenés que llamar por teléfono directamente a la torre de control del aeropuerto (`1.1.1.1`) a través de esa línea para saber si el camino realmente llega.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Restaurar Internet a la empresa en 2 segundos mientras implementás la solución definitiva

En plena caída del ISP 1, subí temporalmente la `distance` de la ruta de `WAN 1` a `10` (o deshabilitala) para que toda la empresa salga ya mismo por `WAN 2`:

```text
# MikroTik:
/ip route set [find gateway=192.168.1.1 and dst-address=0.0.0.0/0] distance=10
```

### 2. Verificar que los DHCP Clients de las bocas WAN no estén inyectando rutas `0.0.0.0/0` bobas con `distance=1`

```text
/ip dhcp-client print
# Si 'add-default-route=yes', cambiarlo a 'add-default-route=no' (o 'default-route-distance=10')
# para controlar nosotros las rutas recursivas!
```

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/ip route print where dst-address=0.0.0.0/0
```

### 2. Acción correctiva permanente por fabricante (Configurar Rutas Recursivas / IP SLA hacia Internet)

#### En MikroTik RouterOS v7 (Failover con Rutas Recursivas `scope=10` y `target-scope=11`)

```text
# 1. Eliminar las rutas 0.0.0.0/0 viejas que apuntaban directo al módem:
/ip route remove [find dst-address=0.0.0.0/0]

# 2. Crear las Rutas Semilla ("Canarios" en Internet):
#    - 1.1.1.1 sale EXCLUSIVAMENTE por el módem del ISP 1 (192.168.1.1) con scope=10 y target-scope=10
#    - 8.8.8.8 sale EXCLUSIVAMENTE por el módem del ISP 2 (198.51.100.1) con scope=10 y target-scope=10
/ip route
add dst-address=1.1.1.1/32 gateway=192.168.1.1  scope=10 target-scope=10 comment="Canario WAN 1 (Cloudflare)"
add dst-address=8.8.8.8/32 gateway=198.51.100.1 scope=10 target-scope=10 comment="Canario WAN 2 (Google)"

# 3. Crear las Rutas 0.0.0.0/0 Recursivas (¡Con target-scope=11 y check-gateway=ping!):
add dst-address=0.0.0.0/0 gateway=1.1.1.1 distance=1 scope=30 target-scope=11 check-gateway=ping comment="WAN 1 Principal Recursiva"
add dst-address=0.0.0.0/0 gateway=8.8.8.8 distance=2 scope=30 target-scope=11 check-gateway=ping comment="WAN 2 Backup Recursiva"
```

#### En Cisco IOS (`IP SLA` + `Track` hacia `1.1.1.1`)

```cisco
configure terminal
ip route 1.1.1.1 255.255.255.255 GigabitEthernet0/0 192.168.1.1 name CANARIO_WAN1

ip sla 1
 icmp-echo 1.1.1.1 source-interface GigabitEthernet0/0
 timeout 2000
 frequency 5
ip sla schedule 1 life forever start-time now

track 1 ip sla 1 reachability
 delay down 10 up 15
exit

no ip route 0.0.0.0 0.0.0.0 192.168.1.1
ip route 0.0.0.0 0.0.0.0 192.168.1.1 1 track 1 name WAN1_RECURSIVA
ip route 0.0.0.0 0.0.0.0 198.51.100.1 10 name WAN2_BACKUP
end
write memory
```

### 3. Rollback

```text
# Si 1.1.1.1 estuviera en mantenimiento, podés agregar un segundo canario para la misma WAN 1 (ej. 9.9.9.9):
/ip route add dst-address=9.9.9.9/32 gateway=192.168.1.1 scope=10 target-scope=10
/ip route add dst-address=0.0.0.0/0 gateway=9.9.9.9 distance=1 scope=30 target-scope=11 check-gateway=ping
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `/ip route print detail where dst-address=0.0.0.0/0` muestra la ruta de `WAN 1` en estado **`Is` (*Inactive*)** (porque la calle del ISP 1 sigue cortada) y la ruta de `WAN 2` en estado **`As` (*Active*)**.
- [ ] Al desconectar el cable coaxial/fibra que entra al módem del ISP 1 (dejando el módem encendido y conectado al router), el router detecta la caída de `1.1.1.1` en 10 segundos y salta a `WAN 2`.
- [ ] **Cómo evitar que vuelva a ocurrir:** Usar siempre **doble canario por proveedor** (`1.1.1.1` y `9.9.9.9` para `WAN 1` con `distance=1`; `8.8.8.8` y `208.67.222.222` para `WAN 2` con `distance=2`) para que ni siquiera una caída puntual de un DNS público dispare un falso failover.

---

## 🔗 Referencias

- [`dual-wan-failover-and-load-balancing`](../../guides/03-routing-l3/dual-wan-failover-and-load-balancing.md) — Guía completa de Rutas Recursivas y Balanceo PCC en RouterOS v7
- [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md) — Concepto de Distancia Administrativa y Rutas Flotantes
