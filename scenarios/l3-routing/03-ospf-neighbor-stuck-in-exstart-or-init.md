⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Dos routers se ven por Ping pero OSPF queda trabado en `ExStart`, `Init` o no instala las rutas

**Dominio:** `l3-routing`
**Nivel:** 🔴 Avanzado
**Capas OSI afectadas:** `Capa 3 (OSPF RFC 2328 — Protocolo IP 89)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS v7`, `Linux FRRouting`

---

## 🎯 Problema

Se configura **OSPFv2** entre un router **Cisco (`R1: 10.0.255.1/30`)** y un router **MikroTik v7 (`R2: 10.0.255.2/30`)** para intercambiar las rutas de las sucursales. El `ping 10.0.255.2` desde el Cisco responde en `1 ms` con `0%` de pérdida, pero **las rutas de la sucursal nunca aparecen en la tabla de enrutamiento** y al mirar los vecinos OSPF el estado se queda congelado en **`ExStart` / `Exchange`** (o en `Init`, o incluso llega a `Full` pero con 0 rutas instaladas!).

```text
+-----------------------------------+    Enlace /30: 10.0.255.0/30    +-----------------------------------+
|         R1 (Cisco IOS)            |      ¡El Ping responde 1ms!     |       R2 (MikroTik v7 / FRR)      |
|  - IP: 10.0.255.1/30              | <=============================> |  - IP: 10.0.255.2/30              |
|  - IP MTU = 1500                  |   Pero OSPF DBD falla porque:   |  - IP MTU = 1480 (o VLAN/PPPoE!)  |
|  - Network Type = Broadcast       |   1) MTU 1500 != 1480 (ExStart) |  - Network Type = Point-to-Point  |
+-----------------------------------+   2) Broadcast != PTP (0 rutas!)+-----------------------------------+
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# Cisco IOS: Ver estado exacto del vecino OSPF, MTU de la interfaz y tipo de red OSPF (BROADCAST vs POINT_TO_POINT)
show ip ospf neighbor
show ip ospf interface Gi0/1 | include Area|Network Type|Timer|MTU
show ip interface Gi0/1 | include MTU

# MikroTik RouterOS v7: Ver estado del vecino OSPF, configuración de interface-template y logs de OSPF
/routing ospf neighbor print detail
/routing ospf interface-template print
/log print where topics~"ospf"

# Linux (FRRouting): Ver vecinos e interfaz OSPF
sudo vtysh -c "show ip ospf neighbor"
sudo vtysh -c "show ip ospf interface"
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Los 3 casos anómalos de OSPF)

```text
# CASO 1 (El más común): Vecino trabado en EXSTART o EXCHANGE que se cae y reinicia cada 40 segundos
R1# show ip ospf neighbor
Neighbor ID     Pri   State           Dead Time   Address         Interface
10.0.0.2          1   EXSTART/DR      00:00:35    10.0.255.2      GigabitEthernet0/1

# CASO 2: Vecino trabado en INIT (o lista vacía en un lado)
10.0.0.2          1   INIT/DROTHER    00:00:38    10.0.255.2      GigabitEthernet0/1

# CASO 3 (La trampa silenciosa): ¡Ambos dicen FULL, pero 'show ip route ospf' está VACÍO!
10.0.0.2          0   FULL/-          00:00:39    10.0.255.2      GigabitEthernet0/1  (Lado PTP)
10.0.0.1          1   FULL/DR         00:00:37    10.0.255.1      ether2              (Lado Broadcast!)
```

**Interpretación de la evidencia:**

- **Si está trabado en `EXSTART` o `EXCHANGE` (Caso 1):** Es **100% diferencia de `IP MTU`** entre ambos lados del enlace (por ejemplo, un lado tiene `1500` y el otro `1480` o `1420`). En el paso `ExStart`, OSPF compara el campo MTU de los paquetes `DBD` y rechaza sincronizar si los números no son idénticos.
- **Si está trabado en `INIT` o vacío (Caso 2):** El firewall `INPUT` de uno de los dos routers está bloqueando el **Protocolo IP `89` (OSPF)** o el multicast **`224.0.0.5`**.
- **Si dice `FULL` en ambos lados pero NO instala ninguna ruta en la tabla (Caso 3):** Un extremo está configurado como **`network-type = point-to-point` (`FULL/-`)** y el otro extremo quedó por defecto como **`network-type = broadcast` (`FULL/DR`)**. Aunque llegan a `Full`, el grafo SPF no coincide (uno espera un LSA Tipo 2 de red con DR y el otro manda solo LSA Tipo 1 punto a punto), por lo que Dijkstra descarta el camino!

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Capa 1 y 2):** El ping directo a `10.0.255.2` responde y los paquetes `Hello` multicast llegan porque ambos routers ven el `Neighbor ID` del otro.
- **Causa raíz (Capa 3 — Máquina de estados OSPF):** OSPF es extremadamente estricto antes de inyectar rutas en el cerebro de la red. Exige coincidencia exacta de: **1) Área, 2) Subred/Máscara, 3) Timers `Hello/Dead`, 4) Autenticación, 5) IP MTU y 6) `Network Type` (`ptp` vs `broadcast`)**.

> **🧠 Modelo mental del incidente:** Pensá en `ExStart` como **dos escribanos que antes de intercambiarse las escrituras de propiedad (`LSDB`) verifican que ambos tengan sobres del mismo tamaño exacto (`MTU`)**: si un escribano dice *"mi sobre mide 1500"* y el otro dice *"mi sobre mide 1420"*, suspenden la firma del contrato aunque estén sentados en la misma mesa.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Comparar los 3 valores críticos (`MTU`, `Network Type` y `Timers`) en ambos routers

```text
# En Cisco IOS:
show ip ospf interface Gi0/1 | include Area|Network Type|Timer|MTU

# En MikroTik RouterOS v7:
/interface print detail where name=ether2-to-r1
/routing ospf interface-template print detail
```

### 2. Verificar la cadena `INPUT` del Firewall si el vecino no pasa de `Init` o no aparece

```text
# En MikroTik RouterOS: Verificar que el Protocolo IP 89 (ospf) esté permitido ANTES del drop final de INPUT!
/ip firewall filter print where chain=input
```

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/routing ospf neighbor print
```

### 2. Acción correctiva por fabricante (Alinear MTU, fijar `point-to-point` y abrir Protocolo `89`)

#### En MikroTik RouterOS v7 (`R2`)

```text
# 1. Permitir Protocolo IP 89 (OSPF) en la cadena INPUT del firewall:
/ip firewall filter
add chain=input protocol=ospf in-interface-list=!WAN action=accept place-before=[find action=drop] comment="Permitir OSPF Proto 89"

# 2. Asegurar que el MTU de la interfaz coincida exactamente con el del vecino (1500 en Ethernet, 1420 en WireGuard):
/interface ethernet set ether2-to-r1 mtu=1500

# 3. Forzar 'type=ptp' (point-to-point) en la plantilla de interfaz OSPF:
/routing ospf interface-template
set [find interfaces=ether2-to-r1] type=ptp cost=10
```

#### En Cisco IOS (`R1`)

```cisco
configure terminal
interface GigabitEthernet0/1
 ! 1. Igualar el MTU y el tipo de red point-to-point con el MikroTik:
 ip mtu 1500
 ip ospf network point-to-point
 ip ospf cost 10
 ! (Nota: Si fuera un enlace donde es imposible cambiar el MTU físico de un lado, podés usar 'ip ospf mtu-ignore')
exit
end
write memory
```

#### En Linux (`FRRouting`)

```bash
sudo vtysh -c "configure terminal" -c "interface eth1" -c "ip ospf network point-to-point" -c "end" -c "write memory"
```

### 3. Rollback

```text
# Reiniciar limpiamente el proceso de vecindad OSPF si quedó cacheado un estado previo:
# Cisco:    clear ip ospf process
# MikroTik: /routing ospf instance disable ospf-instance-1; /routing ospf instance enable ospf-instance-1
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] `show ip ospf neighbor` y `/routing ospf neighbor print` muestran **`State: FULL/-`** (sin `/DR` ni `/BDR` porque ambos están en modo `point-to-point`).
- [ ] `show ip route ospf` y `/ip route print where ospf` listan todas las rutas remotas con flag **`O` / `DAo`** (`Distance 110`).
- [ ] **Cómo evitar que vuelva a ocurrir:** En todo enlace `/30`, `/31` o túnel VPN entre dos routers, **declarar siempre explícitamente `type=ptp` (`ip ospf network point-to-point`)** en ambos extremos en lugar de dejar el modo `broadcast` por defecto.

---

## 🔗 Referencias

- [`routing-fundamentals-static-and-dynamic`](../../concepts/routing-fundamentals-static-and-dynamic.md) — Concepto de OSPF, Distancia Administrativa `110` y tabla LSDB
- [`ospf-single-and-multi-area`](../../guides/03-routing-l3/ospf-single-and-multi-area.md) — Guía completa paso a paso de configuración de OSPF entre Cisco, MikroTik v7 y FRRouting
