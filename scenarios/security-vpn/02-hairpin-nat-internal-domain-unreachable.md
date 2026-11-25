⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Un servidor publicado por Port Forwarding abre desde 4G/Internet pero falla desde el WiFi/LAN de la propia oficina (*Hairpin NAT*)

**Dominio:** `security-vpn`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 3/4 (DNAT / Hairpin NAT)` y `Capa 7 (Split-Horizon DNS)`
**Equipos involucrados:** `MikroTik RouterOS v7`, `Cisco IOS`, `Linux / DNS Local`

---

## 🎯 Problema

Publicaste el servidor web o el grabador de cámaras NVR (`10.1.40.10:443`) hacia Internet mediante un Port Forwarding (`DNAT`) en la IP pública de la empresa (`203.0.113.2` / `erp.empresa.com`). Cuando los directivos prueban desde su celular con **datos móviles 4G, entra al instante**. Pero apenas se conectan al **WiFi o cable de red dentro de la propia oficina, `https://erp.empresa.com` da *Connection Timed Out* o *Connection Reset***.

```text
EL TRIÁNGULO ROTO CUANDO ENTRÁS DESDE ADENTRO USANDO LA IP PÚBLICA:
=======================================================================================
[Laptop en la misma red: 10.1.40.50] ---> 1. Pide ir a 203.0.113.2:443 ---> [RTR-BORDE]
              ^                                                                  |
              |                                     2. El Router hace DNAT a 10.1.40.10
              |                                        (pero deja Origen = 10.1.40.50!)
              |                                                                  v
              +--- 3. ¡El Servidor le contesta DIRECTO por el Switch! --- [Servidor: 10.1.40.10]
                      (La Laptop recibe respuesta desde 10.1.40.10 cuando
                       había hablado con 203.0.113.2 -> ¡La rechaza con TCP RST!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# 1. Desde una PC dentro de la oficina: Ver a qué IP resuelve el dominio (¿da la IP Pública o la IP Privada?)
nslookup erp.empresa.com
dig +short erp.empresa.com

# 2. En MikroTik RouterOS v7: Ver cómo está escrita la regla de dstnat (¿tiene 'in-interface-list=WAN'?)
/ip firewall nat print where chain=dstnat
/ip dns static print
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# 1. En la PC de la oficina:
$ dig +short erp.empresa.com
203.0.113.2   <-- ¡Adentro de la oficina está resolviendo a la IP Pública WAN!

# 2. En MikroTik (/ip firewall nat print):
0 chain=srcnat action=masquerade out-interface-list=WAN
1 chain=dstnat action=dst-nat to-addresses=10.1.40.10 to-ports=443 protocol=tcp in-interface-list=WAN dst-port=443
```

**Interpretación de la evidencia:**

- **Hay dos barreras que impiden que funcione desde adentro:**
  1. La regla de `dstnat` tiene **`in-interface-list=WAN`**: como el pedido de la PC de la oficina entra al router por la interfaz **`LAN`**, la regla `dstnat` ni siquiera se activa!
  2. Si la PC y el Servidor están en la **misma subred/VLAN (`10.1.40.0/24`)**, aunque quites `in-interface-list=WAN`, el servidor le contestará directo a la PC por el switch en Capa 2 (*Triángulo Roto*) y la PC rechazará la respuesta.

---

## 🧠 Diagnóstico por capas

Por qué ocurre este problema y cómo elegir la mejor solución:

- **Solución 1 (Capa 7 — *Split-Horizon DNS*, la más rápida y recomendada para dominios web):** Configurar en el servidor DNS interno del router un registro estático para que cuando alguien **dentro de la oficina** pregunte por `erp.empresa.com`, el DNS le devuelva directamente la IP privada **`10.1.40.10`**. Así el tráfico va directo por el switch a `1 Gbps` sin tocar el NAT del router.
- **Solución 2 (Capa 3/4 — *Hairpin NAT*, obligatoria cuando una app móvil de cámaras usa la IP pública fija o comparten puerto custom):** Ajustar la regla `dstnat` para que filtre por la IP pública (`dst-address=203.0.113.2` o `dst-address-type=local`) y agregar la regla de **Hairpin NAT** en `srcnat`.

> **🧠 Modelo mental del incidente:** Pensá en el *Split-Horizon DNS* como **decirle a un compañero de tu misma oficina que en vez de mandar una carta al correo central con la dirección de la calle del edificio para que vuelva a entrar, camine directamente por el pasillo interno hasta el escritorio `10.1.40.10`**.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Verificar qué servidor DNS están usando las PCs de la oficina

Si las PCs de la oficina tienen puesto `8.8.8.8` directamente en su placa en lugar de la IP de tu router (`10.1.10.1` / `10.1.40.1`), no podrás usar *Split-DNS* hasta que el DHCP les entregue tu DNS interno (o tendrás que usar *Hairpin NAT*).

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/ip firewall nat print
/ip dns static print
```

### 2. Acción correctiva (Implementar AMBAS soluciones en 1 minuto para que funcione tanto por Dominio como por IP Pública)

#### En MikroTik RouterOS v7

```text
# 1. SOLUCIÓN POR SPLIT-HORIZON DNS (Para que por nombre de dominio vaya directo a velocidad de LAN):
/ip dns static
add name=erp.empresa.com address=10.1.40.10 ttl=5m comment="Split-DNS Interno hacia Servidor ERP"

# 2. SOLUCIÓN POR HAIRPIN NAT (Para que también funcione si entran a https://203.0.113.2 o desde la misma VLAN 40):
#    Paso 2.1: En la regla dstnat, reemplazar 'in-interface-list=WAN' por 'dst-address=203.0.113.2'
#              (o si tu IP pública es dinámica: 'dst-address-type=local dst-address=!10.1.0.0/16'):
/ip firewall nat
set [find chain=dstnat and dst-port=443] in-interface-list="" dst-address=203.0.113.2

#    Paso 2.2: Agregar la regla de Hairpin NAT en srcnat (LAN -> misma LAN pasa por Masquerade del router):
add chain=srcnat src-address=10.1.40.0/24 dst-address=10.1.40.0/24 action=masquerade comment="Hairpin NAT VLAN 40"
```

#### En Linux (`dnsmasq` + `nftables`)

```bash
# 1. Split-DNS en /etc/dnsmasq.conf:
echo "address=/erp.empresa.com/10.1.40.10" | sudo tee -a /etc/dnsmasq.conf
sudo systemctl restart dnsmasq

# 2. Hairpin NAT en nftables:
sudo nft add rule ip nat prerouting ip daddr 203.0.113.2 tcp dport 443 dnat to 10.1.40.10:443
sudo nft add rule ip nat postrouting ip saddr 10.1.40.0/24 ip daddr 10.1.40.10 tcp dport 443 masquerade
```

### 3. Rollback

```text
/ip dns static remove [find name=erp.empresa.com]
/ip firewall nat remove [find comment="Hairpin NAT VLAN 40"]
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] Desde adentro de la oficina, `nslookup erp.empresa.com` devuelve `10.1.40.10` y abre en `< 50 ms`.
- [ ] Desde adentro de la oficina, entrar por IP pública directa `https://203.0.113.2` o desde la app de cámaras también conecta gracias al *Hairpin NAT*.
- [ ] Desde un celular en 4G externo sigue abriendo normalmente.
- [ ] **Cómo evitar que vuelva a ocurrir:** Al publicar cualquier servicio interno, crear siempre su entrada correspondiente en `/ip dns static` (*Split-Horizon DNS*) y escribir las reglas de `dstnat` usando `dst-address=<IP_PUBLICA>` en lugar de `in-interface=WAN`.

---

## 🔗 Referencias

- [`tcp-udp-mtu-and-nat-conntrack`](../../concepts/tcp-udp-mtu-and-nat-conntrack.md) — Diagrama paso a paso del "Triángulo Roto" del Hairpin NAT
- [`nat-masquerade-dnat-and-hairpin`](../../guides/04-firewalls-nat-vpn/nat-masquerade-dnat-and-hairpin.md) — Guía completa de configuración de NAT, DNAT y Hairpin NAT
- [`dhcp-dns-and-network-services`](../../concepts/dhcp-dns-and-network-services.md) — Concepto de Split-Horizon DNS
