⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Dos routers VRRP/HSRP actúan como Master al mismo tiempo (*Split-Brain*) causando cortes intermitentes

**Dominio:** `l3-routing`
**Nivel:** 🔴 Avanzado
**Capas OSI afectadas:** `Capa 2 (Multicast / VLAN)` y `Capa 3 (VRRP Protocolo IP 112)`
**Equipos involucrados:** `MikroTik RouterOS v7`, `Cisco IOS`, `Switch Capa 2 / Linux Keepalived`

---

## 🎯 Problema

La empresa tiene dos routers de borde (`RTR-1` con `ISP 1` y `RTR-2` con `ISP 2`) configurados en alta disponibilidad con **VRRP (`VIP: 10.1.10.1`, `VRID 10`)**. Después de aplicar nuevas reglas de hardening en el firewall o cambiar un switch, **los usuarios sufren microcortes cada 20–40 segundos, las videollamadas se caen, el acceso por SSH a los servidores se desconecta y se pierde el 30% de los pings hacia el Default Gateway `10.1.10.1`**.

```text
+---------------------------+                           +---------------------------+
|   RTR-1 (Prioridad 200)   |     Latidos Multicast     |   RTR-2 (Prioridad 100)   |
|   Estado: MASTER (RM)     | ---- 224.0.0.18 ----X---> |   Estado: ¡TAMBIÉN MASTER!|
|   Usa VIP: 10.1.10.1      |   (Bloqueado por Firewall |   Usa VIP: 10.1.10.1      |
|   Usa MAC: 00:00:5E:00:01:0A   INPUT o VLAN en Switch)|   Usa MAC: 00:00:5E:00:01:0A
+---------------------------+                           +---------------------------+
              \                                                       /
               \------> [SW-CORE: ¡MAC Flapping de 00:00:5E...!] <---/
                        (La MAC virtual salta entre el Puerto 1
                         y el Puerto 2 varias veces por segundo!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7 (Ejecutar en AMBOS routers RTR-1 y RTR-2):
/interface vrrp print
/ip firewall filter print where chain=input and protocol=vrrp

# Cisco IOS (Ejecutar en AMBOS routers):
show vrrp brief
show standby brief

# En el Switch Core conectado a ambos routers: Ver si la MAC virtual 00:00:5E:00:01:XX está saltando de puerto
show mac address-table address 0000.5e00.010a
show logging | include MACFLAP
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En RTR-1 (/interface vrrp print):
Flags: R - RUNNING; M - MASTER
#    NAME    INTERFACE     MAC-ADDRESS        VRID  PRIORITY  INTERVAL  VERSION
0 RM vrrp10  vlan10-staff  00:00:5E:00:01:0A    10       200  1s              3

# En RTR-2 (/interface vrrp print):
Flags: R - RUNNING; M - MASTER
#    NAME    INTERFACE     MAC-ADDRESS        VRID  PRIORITY  INTERVAL  VERSION
0 RM vrrp10  vlan10-staff  00:00:5E:00:01:0A    10       100  1s              3
```

**Interpretación de la evidencia:**

- **Tanto `RTR-1` como `RTR-2` tienen los flags `RM` (*Running, Master*) al mismo tiempo** (en estado sano, `RTR-1` debe ser `RM` y `RTR-2` debe ser **`B` — *Backup***).
- Estamos ante un **Split-Brain (Doble Master)**: como `RTR-2` no escucha los latidos de `RTR-1`, cree que `RTR-1` murió y activa la misma IP `10.1.10.1` y la misma MAC `00:00:5E:00:01:0A`, haciendo que el switch mande la mitad de los paquetes a `RTR-1` y la otra mitad a `RTR-2` (rompiendo el estado de Conntrack de todas las sesiones TCP).

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Causa raíz (Por qué `RTR-2` dejó de escuchar a `RTR-1`):**
  1. **Causa #1 (80% de las veces — Firewall `INPUT`):** Al hacer hardening del router y agregar la regla final `chain=input action=drop`, olvidaron permitir el **Protocolo IP `112` (`vrrp`)** (o la dirección destino multicast `224.0.0.18`).
  2. **Causa #2 (Capa 2 — VLAN o IGMP Snooping en el Switch):** La `VLAN 10` no está permitida en el Trunk entre los puertos donde se conectan `RTR-1` y `RTR-2`, o tienen activado *Port Isolation / Horizon* entre ambos puertos.
  3. **Causa #3 (Parámetros VRRP incompatibles):** Un router tiene `version=3` y el otro `version=2`, o tienen distinto `vrid`.

> **🧠 Modelo mental del incidente:** Pensá en el *Split-Brain* como **el Guardia Titular y el Guardia Suplente con el handy roto**: como el Suplente no escucha por el handy que el Titular sigue en la puerta, el Suplente también se pone una gorra idéntica de Jefe y los dos empiezan a tironear de los clientes en el mismo pasillo.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Probar si hay conectividad Capa 2/3 directa entre las IPs físicas de `RTR-1` (`10.1.10.2`) y `RTR-2` (`10.1.10.3`)

```text
# Desde RTR-2 hacer ping a la IP FÍSICA de RTR-1:
/ping 10.1.10.2 src-address=10.1.10.3 count=3
```

- **Si el ping entre `.2` y `.3` NO responde:** El problema está en el **Switch Capa 2** (falta la VLAN 10 en el puerto de uno de los dos routers).
- **Si el ping entre `.2` y `.3` SÍ responde en `0.3 ms`:** La Capa 2 está sana; el problema es el **Firewall `INPUT` bloqueando el Protocolo IP `112`** o discrepancia de versión VRRP.

### 2. Capturar en `RTR-2` si los paquetes VRRP están llegando por el cable antes del firewall

```text
# En RTR-2:
/tool sniffer quick interface=vlan10-staff ip-protocol=vrrp
```

- Si el sniffer en `RTR-2` **SÍ ve** llegar los paquetes `10.1.10.2 -> 224.0.0.18 ip:vrrp`, pero `RTR-2` sigue en `Master (RM)`, es **100% la cadena `INPUT` del propio `RTR-2`** descartándolos (o diferencia de `version=2` vs `version=3`).

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/interface vrrp print detail
/ip address print where interface~"vrrp|vlan10"
```

### 2. Acción correctiva por fabricante

#### En MikroTik RouterOS v7 (Ejecutar en AMBOS routers `RTR-1` y `RTR-2`)

```text
# 1. Permitir explícitamente el Protocolo IP 112 (vrrp) en la cadena INPUT antes del drop final:
/ip firewall filter
add chain=input protocol=vrrp in-interface-list=LAN action=accept place-before=[find action=drop] comment="Permitir latidos VRRP (Proto 112)"

# 2. Asegurar la misma versión (version=3) y VRID en ambos routers:
/interface vrrp
set [find name=vrrp10] version=3 vrid=10 interval=1s preemption-mode=yes

# 3. Verificar que la VIP (.1) tenga máscara /32 y la IP física (.2 o .3) tenga máscara /24:
/ip address
set [find interface=vrrp10] address=10.1.10.1/32
```

#### En Linux (`nftables` / `keepalived`)

```bash
# Permitir protocolo IP 112 (vrrp) en la cadena input de nftables:
sudo nft insert rule inet filter input ip protocol 112 accept
```

### 3. Rollback (Si necesitás apagar VRRP de emergencia en el router secundario)

```text
# En RTR-2 (Suplente):
/interface vrrp disable vrrp10
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] En `RTR-1`, `/interface vrrp print` muestra **`0 RM vrrp10`** (*Running, Master*).
- [ ] En `RTR-2`, `/interface vrrp print` muestra **`0 B vrrp10`** (*Backup*) en menos de 3 segundos.
- [ ] El ping a `10.1.10.1` tiene `0%` de pérdida y en el switch desaparece el *MAC Flapping*.
- [ ] **Cómo evitar que vuelva a ocurrir:** Incluir siempre `protocol=vrrp` (`112`) y `protocol=ospf` (`89`) en las reglas de `INPUT` desde interfaces internas cuando despliegues pares de routers en alta disponibilidad.

---

## 🔗 Referencias

- [`first-hop-redundancy-vrrp-hsrp`](../../concepts/first-hop-redundancy-vrrp-hsrp.md) — Concepto completo de VRRP, HSRP y la anatomía del Split-Brain
- [`vrrp-and-hsrp-gateway-redundancy`](../../guides/03-routing-l3/vrrp-and-hsrp-gateway-redundancy.md) — Guía paso a paso de configuración de VRRP + WAN Tracking
