# Documentación de Menu Timer

Esta carpeta contiene la documentación del proyecto **Menu Timer**, una app
nativa de macOS para la barra de menús (menu bar) que gestiona **temporizadores**,
**alarmas**, **cronómetros** y **pomodoros**.

> **Si vas a tocar código, empieza por [`agent-context/INDEX.md`](./agent-context/INDEX.md).**
> Los tres documentos de abajo describen la app tal como era antes de extraer el
> paquete `MenuTimerKit`: siguen sirviendo para entender el producto y las decisiones
> de diseño, pero no reflejan la estructura actual del repositorio.

La documentación se divide en tres documentos, cada uno con un público y
objetivo distintos:

| Documento | Qué cubre | Para quién |
|---|---|---|
| [**Funcional**](./01-funcional.md) | Qué hace la app, desde el punto de vista del usuario. Casos de uso, flujos y comportamiento. | Usuarios, QA, producto, anyone que quiera entender la app sin leer código. |
| [**Arquitectura**](./02-arquitectura.md) | Cómo está estructurada la app. Componentes, responsabilidades, flujos de datos, decisiones de diseño. | Desarrolladores que se incorporan al proyecto. |
| [**Técnica**](./03-tecnica.md) | Detalles de implementación: modelos, APIs, persistencia, schemas, pruebas, build/release. | Mantenedores que van a tocar el código. |

## Vista rápida

```
Menu Timer
├── Plataforma      macOS 13+ (Ventura), Swift 5.9+
├── UI               Híbrida: AppKit (menubar) + SwiftUI (formularios/About)
├── Persistencia     JSON atómico en ~/Library/Application Support/MenuTimer/store.json
├── Motor            Un único Timer 1 Hz (TickEngine) refresca todos los items
├── Versión          1.5.3 (semver; bump obligatorio por commit de producción)
└── Bundle ID        com.menutimer.MenuTimer
```

> La fuente principal de verdad para temporizadores y alarmas es **`fireDate`**:
> el tiempo restante siempre se deriva como `fireDate - now`, nunca se almacena.
> Este principio recorre los tres documentos.
