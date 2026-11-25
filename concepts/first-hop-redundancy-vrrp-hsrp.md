⬅️ [Volver a Conceptos](README.md)

# Redundancia de Primer Salto (VRRP y HSRP) — Alta disponibilidad del Default Gateway

**Capa OSI principal:** Capa 3 (con ilusión en Capa 2) | **Estándares:** `RFC 5798 (VRRP v3)`, `RFC 3768 (VRRP v2)`, `RFC 2281 (Cisco HSRP)`

---

## 🧠 ¿Qué es?

Aunque tengas dos proveedores de Internet, dos switches y dos routers configurados con OSPF, seguís teniendo un **punto único de falla mortal** en la salida de tu red local: **las computadoras, servidores, cámaras e impresoras solo usan un único Default Gateway estático (`10.1.10.1`)**. Si ese router principal se apaga o se quema su fuente, ninguna PC sabe que al lado hay un segundo router (`10.1.10.3`) listo para trabajar, y toda la empresa se queda sin red.

Los protocolos **FHRP (*First Hop Redundancy Protocols*)** — siendo **VRRP** el estándar universal abierto (usado en MikroTik, Aruba, Ubiquiti, Fortinet y Linux) y **HSRP** la variante propietaria de Cisco — resuelven esto creando una **ilusión perfecta**: dos (o más) routers físicos se ponen de acuerdo para compartir **una misma Dirección IP Virtual (`VIP: 10.1.10.1`) y una misma Dirección MAC Virtual**. Las PCs siempre envían todo a `10.1.10.1`; si el router titular muere, el router suplente toma su IP y su MAC en menos de **3 segundos** sin que haya que tocar nada en ninguna PC.

---

## 🎯 ¿Por qué importa en el día a día?

Sin VRRP/HSRP, actualizar el firmware de tu router principal o cambiarlo por otro equipo significa **cortar toda la empresa**. Con VRRP/HSRP bien configurado, podés reiniciar o apagar el router principal al mediodía en pleno horario laboral y los usuarios pierden como máximo 1 o 2 pings.

- **En diseño:** Es el complemento obligatorio cuando instalás dos routers o firewalls de borde en alta disponibilidad (HA).
- **En operación/mantenimiento:** Te permite pasar el rol de `Master` al router `Backup` cambiando su prioridad con un solo comando antes de hacer una ventana de mantenimiento en el router titular.
- **En troubleshooting:** Si entendés cómo viajan los latidos multicast de VRRP (`224.0.0.18`), podés diagnosticar en 1 minuto el temido escenario de **Split-Brain (Doble Master)** cuando un switch mal configurado bloquea los saludos entre ambos routers.

---

## ⚙️ Cómo funciona por dentro

### 1. La arquitectura de la ilusión: IPs Reales + IP Virtual (VIP) + MAC Virtual

Para implementar VRRP o HSRP en cualquier VLAN, siempre necesitás **3 direcciones IP** de esa subred:

- **Una IP real propia** para el Router Físico A (ej. `10.1.10.2/24`).
- **Una IP real propia** para el Router Físico B (ej. `10.1.10.3/24`).
- **Una IP Virtual compartida (`VIP`)** que será el **Default Gateway de todas las PCs** (ej. `10.1.10.1`).

```text
           [Router Físico A: MASTER]                        [Router Físico B: BACKUP]
           IP Real: 10.1.10.2/24                            IP Real: 10.1.10.3/24
           Prioridad VRRP: 200 (¡Gana!)                     Prioridad VRRP: 100
                    \                                                /
                     \        Latidos Multicast 224.0.0.18          /
                      \       <--- "Sigo vivo (cada 1 seg)" --->   /
                       \                                          /
                        v                                        v
                +--------------------------------------------------------+
                |          ROUTER VIRTUAL (VRID = 10)                    |
                |          IP Virtual (VIP): 10.1.10.1                   |
                |          MAC Virtual:      00:00:5E:00:01:0A           |
                +--------------------------------------------------------+
                                            ||
                                            || (El Switch aprende que 00:00:5E:00:01:0A
                                            ||  está en la boca del Router A. Si A cae,
                                            ||  B dispara Gratuitous ARP y el Switch
                                            ||  mueve esa MAC a la boca de B en 1 ms!)
                                            v
                                  [Switch Capa 2 — VLAN 10]
                                     /                 \
                        [PC-1: GW 10.1.10.1]     [Servidor: GW 10.1.10.1]
```

### Anatomía / Componentes clave del protocolo

| Componente | Valor en VRRP (`RFC 5798`) | Valor en Cisco HSRP (`v1 / v2`) | Función real y por qué es brillante |
|------------|----------------------------|---------------------------------|-------------------------------------|
| **Identificador de Grupo** | **`VRID`** (`1` a `255`, ej. `10` para la VLAN 10) | **`Standby Group`** (`0–255` en v1 / `0–4095` en v2) | Permite tener múltiples instancias virtuales independientes (una por cada VLAN) en el mismo par de routers |
| **Dirección MAC Virtual** | **`00:00:5E:00:01:<VRID_en_Hex>`** (ej. VRID 10 = `...:0A`) | `00:00:0C:07:AC:<Hex>` (v1) / `00:00:0C:9F:F<Hex>` (v2) | Como ambos routers usan **exactamente la misma MAC virtual para el `.1`**, cuando hay failover **las PCs no tienen que actualizar su caché ARP**. Solo el switch actualiza en qué puerto físico está esa MAC |
| **Elección por Prioridad** | `1` a `254` (por defecto **`100`**). **Gana el número MÁS ALTO** | `0` a `255` (por defecto **`100`**). **Gana el número MÁS ALTO** | *(¡Ojo! Al revés que en Spanning Tree, en VRRP/HSRP gana la prioridad más grande: `200` le gana a `100`)* |
| **Latidos (*Heartbeats*)** | Multicast **`224.0.0.18`**, Protocolo IP **`112`**, cada **`1 seg`** | Multicast `224.0.0.2` (v1) o **`224.0.0.102`** (v2), **`UDP 1985`**, cada `3 seg` | Solo el router `Master / Active` transmite latidos. El `Backup / Standby` escucha en silencio. Si pasan **3 intervalos sin escuchar al Master (~3 segundos)**, el Backup se proclama nuevo Master y lanza un *Gratuitous ARP* |
| **Preemption (*Preempt*)** | **`yes` (Activado por defecto)** | **`Desactivado por defecto`** (hay que poner `standby preempt`) | Define si cuando el Router A principal vuelve a encenderse tras un corte de luz, le quita de nuevo el trono de `Master` al Router B (`Preempt = ON`) o lo deja seguir trabajando (`Preempt = OFF`) |

---

### 2. La Trampa Mortal en Producción: Olvidar el *WAN Tracking*

Imaginá este escenario real que le pasa a casi todo el mundo la primera vez que configura VRRP:

```text
   [ISP 1: Fibra Principal]                        [ISP 2: Fibra Backup]
              |                                              |
              X <--- ¡SE CORTA LA FIBRA EN LA CALLE!         | (ISP 2 funciona perfecto)
              |                                              |
         (ether1-wan)                                   (ether1-wan)
   +-----------------------+                      +-----------------------+
   |  ROUTER A (MASTER)    |                      |  ROUTER B (BACKUP)    |
   |  Prioridad VRRP = 200 |                      |  Prioridad VRRP = 100 |
   +-----------------------+                      +-----------------------+
         (ether2-lan)                                   (ether2-lan)
              |                                              |
              +---------> [Switch LAN: VLAN 10] <------------+
                          "Router A sigue mandando latidos VRRP cada 1 seg por la LAN
                           diciendo: ¡ESTOY VIVO Y TENGO PRIORIDAD 200!"
                          Resultado: ¡Router B nunca toma el control y toda la empresa
                                     se queda SIN INTERNET teniendo el Router B sano!
```

**¿Por qué falló el failover si teníamos VRRP?**
Porque VRRP por sí solo **únicamente vigila que el Router A siga encendido del lado de la LAN**. Si al Router A se le corta Internet en su boca WAN (o el proveedor ISP 1 se queda sin tráfico), su interfaz LAN sigue encendida y sigue enviando latidos VRRP con prioridad `200`.

**La solución obligatoria (*WAN Interface / Object Tracking*):**

1. **En Cisco HSRP / VRRP:** Se asocia un **Track Object** (ligado a la interfaz WAN o a un ping *IP SLA* hacia `1.1.1.1`) que, si falla la WAN, **le resta `150` puntos a la prioridad del Router A** (`200 - 150 = 50`). Al bajar a `50`, el Router B (que tiene `100`) le gana instantáneamente y pasa a ser el nuevo `Master`.
2. **En MikroTik RouterOS:** Se combina con un chequeo de salud (*Netwatch* o script en el perfil DHCP/Ruta recursiva) que disminuye la `priority` de la interfaz VRRP de `200` a `50` cuando cae la salida WAN del Router A, o bien se agrega una ruta en el Router A hacia el Router B para no perder los paquetes mientras conmuta.

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

| Concepto FHRP | Cisco IOS (HSRP / VRRP) | MikroTik RouterOS v7 (VRRP) | Aruba / Ubiquiti / Fortinet | Linux (`keepalived`) |
|---------------|-------------------------|-----------------------------|-----------------------------|----------------------|
| **Protocolo recomendado** | `HSRP v2` (solo Cisco) o **`VRRP`** (si mezclás con otra marca) | **`VRRP`** (`/interface vrrp`) | **`VRRP`** | **`VRRP`** (`keepalived`) |
| **Rol del Router Titular** | **`Active`** | **`Master`** (flag `M`) | **`Master`** | **`MASTER`** |
| **Rol del Router Suplente** | **`Standby`** | **`Backup`** (flag `B`) | **`Backup`** | **`BACKUP`** |
| **Dónde se pone la IP Virtual (`VIP`)** | Adentro de la interfaz física/VLAN (`standby 10 ip 10.1.10.1`) | En `/ip address` asignada a la interfaz `vrrp10` con máscara **`/32`** | En el bloque `vrrp 10` de la interfaz VLAN | En `virtual_ipaddress { 10.1.10.1/24 }` de `keepalived.conf` |
| **Seguimiento de caída de WAN** | `track 1 ip sla 1 reachability` + `standby 10 track 1 decrement 150` | Script de *Netwatch* ajustando `/interface vrrp set vrrp10 priority=50` | `vrrp 10 track interface/object` | `track_script { chk_wan }` con `weight -150` |

> **💡 Regla clave en MikroTik RouterOS:** En MikroTik, la IP real del router en la interfaz física/VLAN (`ether2` / `vlan10`) lleva la máscara normal de la red (**`10.1.10.2/24`**), pero la IP Virtual (`VIP`) que le asignás a la interfaz `vrrp10` **SIEMPRE DEBE LLEVAR MÁSCARA `/32` (`10.1.10.1/32`)** cuando pertenece a la misma subred. Si le ponés `/24` a ambas interfaces en el mismo router, creás dos rutas conectadas (`DAC`) idénticas hacia `10.1.10.0/24` y rompés el enrutamiento local cuando el router pasa a estado `Backup`.

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| **Estados en el par de routers (`/interface vrrp print` / `show standby brief`)** | Router A = **`Master (RM)`** y Router B = **`Backup (B)`** | **Ambos routers figuran como `Master (RM)` al mismo tiempo** (*Split-Brain*) | **Los latidos Multicast `224.0.0.18` no están llegando de un router al otro:** falta la VLAN en el trunk del switch intermedio, un firewall `INPUT` bloquea el protocolo IP `112` o difieren el `vrid` / contraseña |
| **MAC aprendida para `10.1.10.1` en la tabla ARP de las PCs** | `00:00:5e:00:01:0a` (MAC virtual VRRP del grupo 10) | Aparece la MAC física real de la placa del router (`d4:ca:6d:...`) | Las PCs están apuntando a la IP física `.2` en vez de a la VIP `.1`, o VRRP no levantó |
| **Tiempo de corte al apagar el Router Master** | Se pierden **`1 a 3 pings`** (`< 3 segundos`) y todo sigue funcionando | Se corta la red durante **`5 minutos`** hasta que vence la caché ARP | Un switch o hipervisor (VMware ESXi / Proxmox) tiene activado **bloqueo de *MAC Spoofing / Forged Transmits*** o un filtro que bloquea el *Gratuitous ARP* de la MAC virtual `00:00:5E...` |
| **Comportamiento cuando se corta el módem WAN del Router Master** | El tracking detecta la caída de Internet, baja la prioridad de A y B pasa a `Master` | El Router A sigue siendo `Master` aunque no tiene Internet | Falta configurar **WAN Tracking** (VRRP solo mira la interfaz LAN si no le agregás seguimiento de la salida WAN) |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Usar HSRP de Cisco cuando en el futuro podés necesitar poner un MikroTik, Fortinet o Linux como respaldo:** HSRP es 100% propietario de Cisco. Los routers Cisco IOS modernos soportan perfectamente el estándar abierto **VRRP** (`vrrp 10 ip 10.1.10.1`). Si estandarizás en **VRRP**, podés armar alta disponibilidad incluso entre un router Cisco principal y un router MikroTik o Linux de contingencia.
- **❌ Bloquear sin querer VRRP en la cadena `INPUT` del firewall:** Cuando aplicás hardening a un router y ponés al final de la cadena `INPUT` una regla `drop all`, si no permitiste explícitamente el **Protocolo IP `112` (VRRP)** o el tráfico desde la subred LAN local, el router Backup deja de escuchar los anuncios multicast `224.0.0.18` del Master, cree que el Master murió y se proclama segundo Master (*Split-Brain*).
- **❌ Olvidar sincronizar las reglas de Firewall/NAT y Port Forwarding entre el Router A y el Router B:** VRRP **solo mueve la IP virtual del Default Gateway**, NO copia las configuraciones de firewall, rutas ni VPNs de un router al otro. Si abriste un puerto o agregaste una ruta estática en el Router A y te olvidaste de replicarla en el Router B, el día que actúe el failover a la madrugada ese servicio dejará de funcionar.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

En un centro de distribución instalan dos routers MikroTik CCR en alta disponibilidad con VRRP (`VIP: 10.1.10.1`, `VRID: 10`). Al principio todo parece andar, pero a las pocas horas los usuarios reportan que **las sesiones SSH y el sistema de facturación se desconectan cada 30 segundos y la mitad de los pings a `10.1.10.1` se pierden**.

### Análisis paso a paso por capas

1. **Síntoma observado:** Pérdida intermitente de paquetes hacia la IP virtual `10.1.10.1` y cortes de sesiones TCP.
2. **Hipótesis usando el modelo mental (Verificación de roles Master/Backup en ambos equipos):**
   - Entramos por SSH a las IPs físicas de ambos routers (`10.1.10.2` y `10.1.10.3`) y ejecutamos `/interface vrrp print`.
3. **Evidencia que lo confirma:**
   - En el Router 1 (`10.1.10.2`): `vrrp10` tiene los flags **`RM` (*Running, Master*)**.
   - En el Router 2 (`10.1.10.3`): `vrrp10` **¡TAMBIÉN tiene los flags `RM` (*Running, Master*)!**
   - Estamos ante un **Split-Brain (Doble Master)**: ambos routers están enviando anuncios con la misma MAC virtual `00:00:5E:00:01:0A`, haciendo que la tabla CAM del switch sufra *MAC Flapping* constante entre el puerto 1 y el puerto 2.
   - ¿Por qué el Router 2 no escuchaba al Router 1? Al revisar `/interface vrrp print detail`, el técnico había puesto `version=3` en el Router 1 y había dejado `version=2` en el Router 2 (además de una regla en el switch que tenía *IGMP Snooping* mal configurado bloqueando el multicast `224.0.0.18`).
4. **Resolución arquitectónica:**
   - Unificamos `version=3` en ambos routers, permitimos el protocolo IP `112` en la cadena `input` de ambos firewalls y ajustamos el switch. Instantáneamente el Router 2 escucha los latidos del Router 1 (prioridad `200`), pasa a estado **`B` (*Backup*)**, desaparece el *MAC Flapping* y la pérdida de paquetes baja a `0%`.

---

## 🧠 Modelo mental

Pensá en esto como **el puesto de guardia en la única puerta de salida de una planta industrial (`10.1.10.1`) atendido por un Guardia Titular (Master) y un Guardia Suplente (Backup)**:

- **Los empleados de la fábrica (las PCs)** no saben cómo se llama el guardia de turno (si es Juan `.2` o Pedro `.3`): ellos solo saben que para salir a la calle tienen que ir a la **Ventanilla #1 (`VIP: 10.1.10.1`)** y hablar con quien tenga puesta **la gorra oficial de Jefe de Salida (`MAC Virtual: 00:00:5E:00:01:0A`)**.
- **Cada 1 segundo**, Juan (el Titular con prioridad `200`) le dice por handy a Pedro: *"Sigo acá en la ventanilla"* (**Latido Multicast `224.0.0.18`**). Mientras escuche eso, Pedro toma mate sentado atrás en silencio.
- **Si Juan se desmaya**, a los 3 segundos de no escuchar el handy, Pedro se levanta de un salto, **se pone la misma gorra oficial (`MAC Virtual`)**, se sienta en la misma Ventanilla #1 (`10.1.10.1`) y grita por el megáfono (**Gratuitous ARP**) para que el conserje del pasillo (el Switch) le mande la fila a su silla. Ningún empleado de la fábrica tuvo que enterarse de que cambió el guardia.
- **Y el *WAN Tracking*** es asegurarse de que si la calle de atrás de la silla de Juan se inunda (se corta su proveedor de Internet), Juan mismo se quite la gorra y le ceda la ventanilla a Pedro, cuya puerta trasera da a una avenida abierta.

---

## 🔗 Ver también

- [`routing-fundamentals-static-and-dynamic`](routing-fundamentals-static-and-dynamic.md) — Cómo se combina VRRP/HSRP del lado LAN con el enrutamiento estático o dinámico (OSPF) del lado WAN
- [`ethernet-mac-and-arp`](ethernet-mac-and-arp.md) — El rol fundamental del *Gratuitous ARP* y la tabla CAM del switch para que la conmutación VRRP tarde milisegundos
- [`tcp-udp-mtu-and-nat-conntrack`](tcp-udp-mtu-and-nat-conntrack.md) — El paso siguiente: subir a Capa 4 (TCP, UDP, ajuste de MTU/MSS y cómo funciona NAT/Conntrack)
