# 🧪 Lab NN — <Título Técnico del Laboratorio> (`docker-compose.<nombre>.yml`)

**Conceptos y guías que aplica:**

- [`<concepto>`](../concepts/<archivo>.md)
- [`<guía>`](../guides/<dominio>/<archivo>.md)
- [`<escenario>`](../scenarios/<dominio>/<archivo>.md)

---

## 🗺️ Topología del Laboratorio

```text
(Diagrama ASCII claro con nombres de contenedores, interfaces eth0/eth1, VLANs e IPs)
```

---

## 🚀 Levantar el entorno

```bash
docker compose -f labs/docker-compose.<nombre>.yml up -d
```

---

## 🔬 Ejercicios Guiados Paso a Paso

### Ejercicio 1: Verificación del estado sano (Baseline)

```bash
docker exec -it <contenedor> <comando>
```

### Ejercicio 2: Provocar y diagnosticar la falla real (Break & Fix)

```bash
# 1. Inyectar la falla
docker exec -it <contenedor> <comando-que-rompe>

# 2. Observar el síntoma y diagnosticar
docker exec -it <contenedor> <comando-diagnostico>

# 3. Restaurar el servicio (Rollback)
docker exec -it <contenedor> <comando-que-repara>
```

---

## 🧹 Apagar y limpiar el laboratorio

```bash
docker compose -f labs/docker-compose.<nombre>.yml down
```
