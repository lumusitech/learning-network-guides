⬅️ [Volver a Conceptos](README.md)

# <Título del concepto> — <Subtítulo accionable y específico>

**Capa OSI principal:** Capa <1..7> (<Nombre de capa>) | **Estándares:** `<IEEE / RFC relacionados>`

---

## 🧠 ¿Qué es?

<Definición directa en 2-3 párrafos cortos. Qué mecanismo o protocolo es, qué problema físico o lógico resuelve en una red real y en qué momento del flujo de tráfico interviene.>

---

## 🎯 ¿Por qué importa en el día a día?

<Consecuencias reales de no entender este concepto al administrar o diseñar una red. Qué incidentes provoca en producción (cortes, bucles, lentitud, agujeros de seguridad, incompatibilidad entre marcas).>

- **En diseño:** <impacto al armar la topología o elegir equipamiento>
- **En operación/mantenimiento:** <impacto en cambios cotidianos>
- **En troubleshooting:** <qué síntoma te hace mirar acá en los primeros 2 minutos>

---

## ⚙️ Cómo funciona por dentro

<Explicación técnica profunda pero clara del mecanismo paso a paso. Dividir en subsecciones `###` según el tema (ej. estructura de trama/paquete, negociación, máquina de estados, tablas en memoria).>

### Diagrama de flujo / estructura

```text
<Diagrama ASCII claro mostrando el flujo de tramas/paquetes, encapsulamiento o topología>
```

### Anatomía / Componentes clave

| Campo / Componente | Tamaño / Valor típico | Función real | Qué pasa si está mal |
|--------------------|-----------------------|--------------|----------------------|
| `<campo 1>` | `<valor>` | `<qué hace>` | `<síntoma de fallo>` |
| `<campo 2>` | `<valor>` | `<qué hace>` | `<síntoma de fallo>` |

---

## 🔄 Diccionario Multi-Vendor (Estándar vs Fabricantes)

<Cómo se llama este mismo concepto estándar cuando abrís la consola o interfaz web de cada fabricante:>

| Concepto Estándar (IEEE/IETF) | Cisco IOS / Catalyst | MikroTik RouterOS | Aruba / Ubiquiti / TP-Link | Linux (`iproute2` / `bridge`) |
|-------------------------------|----------------------|-------------------|----------------------------|-------------------------------|
| `<Término estándar 1>` | `<Término Cisco>` | `<Término MikroTik>` | `<Término Genérico>` | `<Término Linux>` |
| `<Término estándar 2>` | `<Término Cisco>` | `<Término MikroTik>` | `<Término Genérico>` | `<Término Linux>` |

---

## 📊 Señales normales vs anómalas (Diagnóstico)

| Señal / Métrica | Comportamiento Normal (Baseline) | Comportamiento Anómalo | Causa raíz más probable |
|-----------------|----------------------------------|------------------------|-------------------------|
| `<señal 1>` | `<valor esperado>` | `<valor roto>` | `<causa técnica>` |
| `<señal 2>` | `<valor esperado>` | `<valor roto>` | `<causa técnica>` |
| `<señal 3>` | `<valor esperado>` | `<valor roto>` | `<causa técnica>` |

---

## ⚠️ Errores de concepto comunes (Antipatrones)

- **❌ Creer que <mito común 1>:** <Realidad técnica y por qué ocurre el error>.
- **❌ Mezclar <concepto A> con <concepto B>:** <Diferencia exacta entre ambos>.
- **❌ Configurar <acción peligrosa> sin prever <consecuencia>:** <Qué rompe en producción>.

---

## 📖 Caso real: Aplicando el concepto en producción

### El escenario

<Descripción de 2-3 líneas de un problema cotidiano en una empresa/ISP/oficina con equipos reales (ej. un router MikroTik conectado a un switch Cisco o un enlace de fibra/cobre entre pisos).>

### Análisis paso a paso por capas

1. **Síntoma observado:** <qué reporta el usuario o el monitoreo>.
2. **Hipótesis usando el modelo mental:** <qué capa o mecanismo de este documento está actuando>.
3. **Evidencia que lo confirma:** <qué contador, estado o comportamiento del protocolo delata la causa>.
4. **Resolución arquitectónica:** <cómo se corrige de raíz respetando el estándar>.

---

## 🧠 Modelo mental

Pensá en esto como <analogía física cotidiana, concreta y memorable que explique exactamente las reglas del protocolo en 30 segundos>.

<Segundo párrafo breve conectando las piezas de la analogía con los elementos técnicos reales para fijar la intuición.>

---

## 🔗 Ver también

- [`<concepto-relacionado>`](<concepto-relacionado>.md) — <relación directa con este concepto>
- [`<otro-concepto>`](<otro-concepto>.md) — <relación directa con este concepto>
