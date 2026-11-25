⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: La mitad de las PCs de la oficina reciben una IP `192.168.0.x` falsa y pierden acceso a la red (*Rogue DHCP Server*)

**Dominio:** `security-vpn`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 2 (Switching / DHCP Snooping)` y `Capa 7 (DHCP UDP 67/68)`
**Equipos involucrados:** `Cisco IOS`, `MikroTik RouterOS`, `Aruba / Switches Gestionables`

---

## 🎯 Problema

A medida que los empleados encienden sus computadoras por la mañana, **la mitad puede trabajar normal y la otra mitad no tiene acceso ni al sistema ERP local ni a Internet**. Al revisar una de las PCs afectadas, tiene asignada por DHCP la IP **`192.168.0.104/24`** con puerta de enlace **`192.168.0.1`**, cuando toda la empresa usa la subred **`10.1.10.0/24`**.

```text
[RTR-BORDE Oficial: 10.1.10.1] ===(Puerto 1)===> [SW-ACCESO] <===(Puerto 19)=== [Router WiFi Hogareño TP-Link]
 (DHCP Oficial: 10.1.10.x)                            |                         (Enchufado por su boca LAN!
                                                      v                          Reparte 192.168.0.x a gritos!)
                                           [PCs de la Oficina]
                                    (Aceptan el DHCP Offer que llegue 1ms antes!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# 1. En el Router MikroTik Oficial: Activar el detector de servidores DHCP intrusos (DHCP Alert)
/ip dhcp-server alert add interface=vlan10-staff valid-server=D4:CA:6D:01:02:03 disabled=no
/ip dhcp-server alert print

# 2. Desde una PC afectada (o haciendo un test en Linux): Ver la dirección MAC del falso gateway 192.168.0.1
arp -a
ip neigh show

# 3. En el Switch (Cisco / MikroTik / Aruba): Buscar en qué boca física vive esa MAC intrusa!
show mac address-table address 50c7.bfaa.bbcc
/interface bridge host print where mac-address=50:C7:BF:AA:BB:CC
show mac-address 50c7.bfaa.bbcc
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/ip dhcp-server alert print + /log print):
09:14:22 dhcp,critical,error,warning,info,debug dhcp alert on vlan10-staff: discovered unknown dhcp server, mac 50:C7:BF:AA:BB:CC, ip 192.168.0.1

# En el Switch Cisco (show mac address-table address 50c7.bfaa.bbcc):
          Mac Address Table
-------------------------------------------
Vlan    Mac Address       Type        Ports
----    -----------       --------    -----
  10    50c7.bfaa.bbcc    DYNAMIC     Gi1/0/19
```

**Interpretación de la evidencia:**

- La alerta descubrió un servidor DHCP desconocido con la MAC **`50:C7:BF:AA:BB:CC`** (OUI `50:C7:BF` = **TP-Link**) e IP `192.168.0.1`.
- La tabla CAM del switch delata con precisión quirúrgica que esa MAC está conectada físicamente en el puerto **`Gi1/0/19`**.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo descartar pistas falsas:

- **Hipótesis descartada (Falla del servidor DHCP oficial):** El servidor DHCP oficial está sano; por eso el 50% de las PCs que recibieron la respuesta del router oficial un milisegundo antes sí están trabajando normal.
- **Causa raíz (Capa 2 + Capa 7 — Competencia de Broadcast en el ciclo DORA):** Como el paso 1 de DHCP (`Discover`) es un grito en Broadcast a toda la VLAN, tanto el router oficial como el router hogareño enchufado en el puerto 19 lo escuchan y ambos responden un `DHCP Offer`. El cliente acepta el primero que toca su placa de red.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **un empleado en el pasillo que saca un talonario falso y empieza a repartirles credenciales truchas a las personas que entran al edificio antes de que lleguen al mostrador de recepción oficial**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Aislar al intruso en 10 segundos apagando su puerto en el switch

```text
# En Cisco IOS:
configure terminal
interface GigabitEthernet1/0/19
 shutdown
exit

# En MikroTik Switch:
/interface ethernet disable ether19
```

### 2. Forzar a las PCs afectadas a renovar su IP ahora contra el servidor oficial

En las PCs afectadas, ejecutar `ipconfig /release && ipconfig /renew` (Windows) o `sudo dhclient -r && sudo dhclient` (Linux), o apagar y encender un segundo los puertos de acceso del switch para que al detectar reconexión de cable todas las PCs pidan DHCP de nuevo automáticamente.

---

## 🧯 Mitigación y Rollback

> ⚠️ **Regla de Oro antes de activar DHCP Snooping:** **PRIMERO** marcá como **`Trusted`** el puerto Trunk (`Puerto 1`) que sube hacia el router DHCP oficial. Si activás `dhcp-snooping` sin marcar antes el uplink como `trusted`, ¡bloquearás también al servidor oficial!

### 1. Verificar antes de tocar

```text
show interfaces trunk
/interface bridge port print
```

### 2. Acción correctiva permanente por fabricante (Activar **DHCP Snooping**)

Con **DHCP Snooping** activo, aunque mañana otro empleado traiga diez routers hogareños y los enchufe en cualquier oficina, el switch destruirá silenciosamente sus paquetes `DHCP Offer / ACK` (`UDP 67`) sin afectar a una sola PC:

#### En Cisco IOS (`SW-ACCESO`)

```cisco
configure terminal
! 1. Marcar el Puerto 1 (Uplink hacia el Router DHCP Oficial) como TRUSTED:
interface GigabitEthernet1/0/1
 ip dhcp snooping trust
exit

! 2. Encender DHCP Snooping en las VLANs y desactivar Option 82:
ip dhcp snooping
ip dhcp snooping vlan 10,100,200
no ip dhcp snooping information option

! 3. Limitar tasa de pedidos DHCP en bocas de usuarios:
interface range GigabitEthernet1/0/2 - 24
 ip dhcp snooping limit rate 15
exit
end
write memory
```

#### En MikroTik RouterOS v7 (`SW-ACCESO`)

```text
# 1. Marcar el puerto Trunk hacia el Router Oficial como 'trusted=yes' y el resto como 'trusted=no':
/interface bridge port
set [find interface=ether1] trusted=yes
set [find interface!="ether1"] trusted=no

# 2. Encender DHCP Snooping en el bridge1:
/interface bridge
set bridge1 dhcp-snooping=yes add-dhcp-option82=no
```

#### En Aruba / HP ProCurve

```text
configure
dhcp-snooping
dhcp-snooping vlan 10 100 200
no dhcp-snooping option 82
dhcp-snooping trust 1
write memory
```

### 3. Rollback

```text
# Si olvidaste un trunk intermedio y se corta el DHCP:
# Cisco:    no ip dhcp snooping
# MikroTik: /interface bridge set bridge1 dhcp-snooping=no
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] Todas las PCs reciben IP dentro del rango oficial `10.1.10.100–240` con Gateway `10.1.10.1`.
- [ ] `show ip dhcp snooping` / `/interface bridge port print where trusted=yes` confirma que únicamente el uplink al router oficial es `Trusted`.
- [ ] **Cómo evitar que vuelva a ocurrir:** Mantener **DHCP Snooping** activo por estándar en absolutamente todos los switches de acceso de la empresa.

---

## 🔗 Referencias

- [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md) — Concepto del ciclo DORA y anatomía del ataque Rogue DHCP
- [`l2-security-dhcp-snooping-dai-portsec`](../../guides/02-switching-l2/l2-security-dhcp-snooping-dai-portsec.md) — Guía completa de configuración de DHCP Snooping, DAI y Port Security
