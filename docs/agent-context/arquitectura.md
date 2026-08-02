---
actualizado: 2026-08-02
archivos:
  - Package.swift
  - MenuTimer.xcodeproj/project.pbxproj
  - CLAUDE.md
  - MenuTimer/App/AppDelegate.swift
---

# Arquitectura

## Stack

macOS 14+, Swift 5.9. AppKit para la barra de menús y las ventanas; SwiftUI para
formularios y para el listado que consume Widomin. El estado vive en `TimerStore`
(`ObservableObject`, `@MainActor`); la persistencia es un `actor` en background.

## El repo produce dos cosas a la vez

1. **App standalone `MenuTimer`** — target de `MenuTimer.xcodeproj`, fuentes en
   `MenuTimer/`. Menú clásico de `NSMenu` colgando del icono.
2. **Paquete `MenuTimerKit`** — producto SPM declarado en `Package.swift`, fuentes en
   `Sources/MenuTimerKit/`. Lo consume `widomin-app` como módulo.

## Trampa principal: las fuentes están duplicadas

`MenuTimer/` y `Sources/MenuTimerKit/` contienen **copias literales** de los mismos
archivos, no enlaces simbólicos. La única diferencia son los modificadores `public`,
que solo lleva la copia del paquete.

Archivos duplicados hoy: `Models/TimerItem`, `Models/PersistedStore`, `Store/TimerStore`,
`Engine/TickEngine`, `Engine/FireScheduler`, `Persistence/*`, `Services/NotificationService`,
`Utilities/*`, `Forms/*`.

**Al tocar lógica hay que editar las dos copias.** Si solo cambias una, la app y el
paquete divergen en silencio: compilan las dos y se comportan distinto. Comprobación:

```bash
diff MenuTimer/Store/TimerStore.swift Sources/MenuTimerKit/Store/TimerStore.swift
```

No es duplicación exclusiva de cada mundo: `MenuTimer/MenuUI/` (el menú `NSMenu`) y
`Sources/MenuTimerKit/Views/` (el listado SwiftUI) sí son propios de cada consumidor.
`WindowPresenter` existe en ambos sitios pero con API distinta — ver `interfaz/`.

## Convenciones

- Texto de usuario en español en las vistas del Kit; los títulos de ventana de los
  formularios siguen en inglés («Add Timer»).
- Comentarios que explican *por qué*, no *qué*. Respeta ese registro.
- Conventional commits: el hook de `.githooks/` sube `MARKETING_VERSION`.

## Arrancar y probar

```bash
swift build                                    # solo el paquete
xcodebuild -project MenuTimer.xcodeproj -scheme MenuTimer build
xcodebuild test -project MenuTimer.xcodeproj -scheme MenuTimer
```

Los tests de `MenuTimerTests/` hacen `@testable import MenuTimer`: cubren **el target
de la app, no el paquete**. `MenuTimerKit` no tiene tests propios, así que un cambio
hecho solo en `Sources/` no lo valida nadie.

## Trampas

- `CLAUDE.md` dice «macOS 13+» y «Current version: 1.6.5»; ambas cosas están
  desfasadas: `Package.swift` exige macOS 14 y la versión va por 1.9.x.
- `docs/01-funcional.md`, `02-arquitectura.md` y `03-tecnica.md` son de julio y
  describen el estado anterior a `MenuTimerKit`. Este directorio manda.
