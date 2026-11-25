⬅️ [Volver a Escenarios](../README.md)

# 🧩 Escenario: Clientes WiFi quedan "pegados" a un AP lejano con mala señal y las videollamadas se cortan al caminar (*Sticky Clients*)

**Dominio:** `wireless`
**Nivel:** 🟡 Intermedio
**Capas OSI afectadas:** `Capa 1 (Radiofrecuencia 2.4/5 GHz)` y `Capa 2 (IEEE 802.11k/v/r Roaming)`
**Equipos involucrados:** `Ubiquiti UniFi`, `MikroTik WiFi v7`, `Aruba / Cisco WLC`

---

## 🎯 Problema

En una oficina con 6 puntos de acceso WiFi, cuando un gerente camina con su laptop o celular desde su despacho (`AP-DESPACHO`) hasta la Sala de Directorio (`AP-DIRECTORIO`, a 25 metros), **se le corta la llamada de Teams/Zoom y el navegador queda sin respuesta, aunque en la Sala de Directorio tiene un AP nuevo instalado en el techo justo arriba de su cabeza**. Al mirar el icono de WiFi de su laptop, sigue marcando 3 rayitas pero está conectado al `AP-DESPACHO` lejano a `-82 dBm` en la banda `2.4 GHz`.

```text
[AP-DESPACHO (A 25 metros)]                                [AP-DIRECTORIO (A 2 metros!)]
Potencia TX 2.4G = 26 dBm (¡Gritando al 100%!)             Canal 36 (5GHz) / Canal 6 (2.4GHz)
       |                                                                ^
       | El celular todavía escucha el grito lejano a -78 dBm           | (¡Nunca salta a este AP
       +==================> [Laptop/Celular en Sala Directorio] --X-----+  porque 2.4G está demasiado
                             (Transmite con solo 14 dBm:                   fuerte y falta 802.11k/v/r!)
                              el AP lejano NO la escucha!)
```

---

## ⚡ Quick command (NetOps Triage en 30 segundos)

```text
# MikroTik RouterOS v7 (WiFi / CAPsMAN): Ver clientes con señal peor a -72 dBm y a qué banda/AP están pegados
/interface wifi registration-table print stats where signal<-72
/interface wifi print detail

# Ubiquiti UniFi (Por SSH en el AP): Ver clientes asociados con su RSSI, canal y tasa TX/RX
mca-cli-op dump-short

# Linux (Desde la laptop afectada): Ver BSSID (MAC del AP al que está conectada), frecuencia y señal en dBm
iw dev wlan0 link
```

---

## ✅ Salida esperada vs Salida anómala

### Lo que encontrás durante el incidente (Anómalo)

```text
# En MikroTik (/interface wifi registration-table print stats):
Columns: INTERFACE, SSID, MAC-ADDRESS, UPTIME, SIGNAL, TX-RATE, RX-RATE
# INTERFACE           SSID           MAC-ADDRESS        UPTIME  SIGNAL  TX-RATE   RX-RATE
0 ap-despacho-2ghz    Empresa-Staff  A4:83:E7:11:22:33  3h10m   -82     6.0Mbps   1.0Mbps

# Configuración de radio encontrada en los APs:
  2.4 GHz: Channel=Auto (todos en Canal 1!), Width=40MHz, Tx-Power=Auto (26 dBm / High!)
  5.0 GHz: Channel=Auto, Width=80MHz, Tx-Power=Auto (23 dBm)
  Fast Roaming (802.11r / ft): disabled
```

**Interpretación de la evidencia:**

- El cliente lleva `3h10m` aferrado a la radio de **`2.4 GHz` del `AP-DESPACHO`** con señal **`-82 dBm`** y velocidad de recepción de apenas **`1.0 Mbps`**.
- ¿Por qué no saltó al `AP-DIRECTORIO`? **La decisión de hacer roaming la toma el cliente (la laptop/iPhone), NO el AP**, y la mayoría de las placas WiFi no buscan otro AP mientras sigan escuchando al AP actual por encima de `-75 dBm`. Como la radio de `2.4 GHz` estaba al `100%` de potencia (`26 dBm`), la laptop sigue escuchando el grito del AP lejano y nunca lo suelta.

---

## 🧠 Diagnóstico por capas

Las 3 fallas de configuración que causan el síndrome del *Sticky Client*:

1. **Potencia TX de `2.4 GHz` demasiado alta (Celdas gigantes superpuestas):** Si `2.4 GHz` transmite a la misma potencia que `5 GHz`, `2.4 GHz` llega el doble de lejos (+6 dB), por lo que los dispositivos se pasan a `2.4 GHz` y se quedan pegados al primer AP que vieron al entrar al edificio.
2. **Falta de `IEEE 802.11k/v/r` (*Fast Roaming & BSS Transition*):** Sin `802.11k` (lista de vecinos), `802.11v` (sugerencia de cambio de AP) y `802.11r` (*Fast Transition* en `< 50 ms`), cuando el cliente finalmente suelta al AP viejo, tarda 1 a 3 segundos en escanear todos los canales y re-negociar WPA2/WPA3, cortando la llamada de Teams/VoIP.
3. **Canales solapados y ancho de `40 MHz` en `2.4 GHz`:** Poner `40 MHz` en `2.4 GHz` destruye todo el espectro disponible.

> **🧠 Modelo mental del incidente:** Pensá en esta falla como **un salón con 6 megáfonos al volumen máximo**: aunque te mudes de la mesa 1 a la mesa 6, seguís escuchando los alaridos del megáfono de la mesa 1 en tu oído. Tenés que **bajar el volumen de todos los megáfonos** para que cuando te alejes 10 metros de la mesa 1 dejes de escucharla y escuches claramente solo al parlante de la mesa 6.

---

## 🛠️ Procedimiento paso a paso (Runbook de diagnóstico)

### 1. Identificar todos los clientes con señal peor a `-74 dBm` en el controlador

Cualquier cliente estacionario trabajando a `-75 dBm` o `-82 dBm` en una oficina donde sí hay APs cercanos es la prueba de que la potencia TX de los APs está demasiado alta.

### 2. Auditar qué canales y qué potencia (`dBm`) están usando los APs contiguos

Verificar que dos APs vecinos jamás compartan el mismo canal (`1, 6, 11` en `2.4 GHz`; `36, 44, 52, 60, 149, 157` en `5 GHz`).

---

## 🧯 Mitigación y Rollback

### 1. Verificar antes de tocar

```text
/interface wifi print detail
```

### 2. Acción correctiva por fabricante (Bajar potencia 2.4G a `12–14 dBm`, 5G a `18–20 dBm` y activar `802.11k/v/r`)

#### En MikroTik RouterOS v7 (`/interface wifi`)

```text
# 1. Activar Fast Roaming (802.11r: ft=yes, ft-over-ds=yes) en el perfil de seguridad:
/interface wifi security
set [find name=sec-staff] ft=yes ft-over-ds=yes

# 2. Ajustar potencias (Regla de oro: 2.4GHz siempre 6 dB más bajo que 5GHz!) y fijar anchos de canal limpios:
/interface wifi
set [find channel.band~"2ghz"] channel.width=20mhz channel.tx-power=13
set [find channel.band~"5ghz"] channel.width=20/40mhz-Ce channel.tx-power=19

# 3. (Opcional — Regla de Access List para expulsar suavemente clientes debajo de -80 dBm solo si hay otro AP al lado):
/interface wifi access-list
add action=accept signal-range=-80..120
add action=reject signal-range=-120..-81 comment="Expulsar sticky clients extremos (< -81 dBm)"
```

#### En Ubiquiti UniFi / Aruba / TP-Link Omada

1. **En Configuración de cada AP (Radios):**
   - **Radio `2.4 GHz`:** Ancho de canal = **`20 MHz`**; Canales fijos alternados (**`1`, `6` u `11`**); Transmit Power = **`Custom: 13 dBm` (o `Low`)**.
   - **Radio `5 GHz`:** Ancho de canal = **`40 MHz`**; Canales fijos no solapados (**`36`, `44`, `149`, `157`**); Transmit Power = **`Custom: 19 dBm` (o `Medium`)**.
2. **En Configuración del SSID (`"Empresa-Staff"`):**
   - Activar **`Fast Roaming (802.11r)`** = `ON`.
   - Activar **`BSS Transition (802.11v)`** = `ON`.
   - Activar **`Band Steering` (Prefer 5GHz)** = `ON`.
   - Configurar **`Minimum Data Rate Control`** en `2.4 GHz` a **`12 Mbps`** (deshabilita las tasas prehistóricas 802.11b de `1, 2, 5.5 y 11 Mbps`, reduciendo a la mitad el tamaño de la celda fantasma de 2.4 GHz!).

### 3. Rollback

```text
# Si una impresora o lector de código de barras viejo de depósito no soporta 802.11r (Fast Transition):
# Mantener 802.11r activo en "Empresa-Staff" y conectar los lectores viejos al SSID "Empresa-IoT" (con 802.11r apagado).
```

---

## ✅ Verificación post-incidente y Prevención

- [ ] Al caminar del despacho a la Sala de Directorio con una llamada o un `ping -i 0.2 10.1.10.1` corriendo, la laptop salta al `AP-DIRECTORIO` cuando la señal del AP anterior baja a `-70 dBm`, perdiendo `0` o `1` solo paquete (`< 50 ms`).
- [ ] En la tabla de clientes, el `90%+` de las laptops y celulares modernos aparecen asociados en la banda de **`5 GHz`** con señal entre **`-45 dBm` y `-67 dBm`**.
- [ ] **Cómo evitar que vuelva a ocurrir:** **Nunca dejar la potencia TX de los APs en `Auto / High`** (en `Auto`, casi todas las marcas ponen el 100% de potencia máxima). Aplicar siempre la regla **`13 dBm` (2.4G) / `19 dBm` (5G)** en oficinas con múltiples APs.

---

## 🔗 Referencias

- [`enterprise-wifi-vlans-and-roaming`](../../guides/05-wireless-poe/enterprise-wifi-vlans-and-roaming.md) — Guía completa de configuración de WiFi Corporativo, canales y roaming
- [`ieee-and-ietf-networking-standards`](../../reference/ieee-and-ietf-networking-standards.md) — Estándares `802.11k`, `802.11v`, `802.11r` y `802.11w`
