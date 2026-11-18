# ByteFix Optimizer

Herramienta integral de optimización, reducción de input lag, telemetría y mantenimiento para Windows.

## 🚀 Cómo ejecutar con tus clientes

Abre **PowerShell como Administrador** y ejecuta cualquiera de los siguientes comandos directos:

### Opción 1: Suite Completa con Interfaz Gráfica (WPF / XAML)
Interfaz gráfica completa con catálogo de tweaks, desinstalación de bloatware, ajustes avanzados y backup de registro:

```powershell
irm https://raw.githubusercontent.com/Dxb-2004/ByteFix/main/ByteFix.ps1 | iex
```

### Opción 2: Versión Ligera de Consola (ByteFix-Lite)
Versión limpia y directa por terminal con apartado especializado para **reducir el Input Lag al máximo**, juegos, telemetría, limpieza y rendimiento:

```powershell
irm https://raw.githubusercontent.com/Dxb-2004/ByteFix/main/ByteFix-Lite.ps1 | iex
```

---

## ⚡ Apartado de Reducción Máxima de Input Lag
La opción dedicada de Input Lag optimiza:
* **Mouse Raw Input:** Desactiva aceleración de puntero y aplica curvas lineales 1:1 planas (elimina suavizado).
* **Teclado:** Retardo mínimo de repetición (`KeyboardDelay = 0`) y velocidad máxima (`KeyboardSpeed = 31`).
* **Puertos USB:** Desactiva la suspensión selectiva de USB para evitar micro-retrasos de sondeo (*polling rate drops*).
* **GPU & DWM:** Activa HAGS (*Hardware-Accelerated GPU Scheduling*) y fuerza el modo exclusivo FSE.
* **Kernel & CPU:** Desactiva *Power Throttling* y estabiliza el temporizador de alta precisión (*Dynamic Tick off*).

---

## 📁 Archivos incluidos
* `ByteFix.ps1`: Suite gráfica completa compilada con recursos embebidos.
* `ByteFix-Lite.ps1`: Optimizador rápido de línea de comandos con módulo extremo de Input Lag.
