---
dominio: interfaz
actualizado: 2026-08-02
archivos:
  - MenuTimer/MenuUI/StatusItemController.swift
  - MenuTimer/MenuUI/MenuBuilder.swift
  - MenuTimer/MenuUI/MenuRefresher.swift
  - MenuTimer/MenuUI/TimerRowView.swift
  - MenuTimer/MenuUI/BlockMenuItem.swift
  - Sources/MenuTimerKit/Views/MenuTimerMainView.swift
  - Sources/MenuTimerKit/Views/MenuTimerRow.swift
depende_de: [items/_dominio, formularios/_dominio]
---

# Interfaz

Hay **dos interfaces distintas** sobre el mismo `TimerStore`, y no comparten código:

| Consumidor | Dónde | Tecnología |
|---|---|---|
| App standalone | `MenuTimer/MenuUI/` | `NSMenu` colgando del `NSStatusItem` |
| Widomin | `Sources/MenuTimerKit/Views/` | SwiftUI dentro del popover del anfitrión |

Tocar una **no** cambia la otra. Es el error más fácil de cometer en este repo.

## Interfaz de la app standalone

- `StatusItemController` — dueño del `NSStatusItem` y del `NSMenu`. Reconstruye el
  menú al abrirlo (`NSMenuDelegate`) y recibe por closures las acciones de presentar
  formularios.
- `MenuBuilder` — arma los `NSMenuItem` a partir de los items.
- `MenuRefresher` — actualiza **solo los textos** de las filas visibles cada segundo,
  sin reconstruir el menú. Las filas cuyo item ya no existe se dejan como están: el
  menú se rehace al siguiente abrir.
- `TimerRowView` / `BlockMenuItem` — la fila y un `NSMenuItem` que ejecuta un closure,
  para no repartir `@objc` target/action por todo el código.

## Interfaz de Widomin

- `MenuTimerMainView(store:presenter:)` — listado agrupado más la botonera de crear.
  Ver [Listado de Widomin](listado-widomin.md).
- `MenuTimerRow` — la fila, con acciones opcionales de editar y eliminar.

## Trampas

- La cuenta atrás **no la refresca el tick** (ver `disparo/`). En la app la refresca
  `MenuRefresher`; en el listado SwiftUI, un `TimelineView` periódico. Quitar
  cualquiera de los dos congela los tiempos sin romper nada más, así que el síntoma
  aparece lejos de la causa.
- `MenuTimerRow` es `public` y su `init` tiene `onEdit`/`onDelete` con valor por
  defecto `nil`: así sigue valiendo como fila de solo lectura y añadirlos no rompió la
  API.
- Las etiquetas visibles del Kit están en español; los títulos de las ventanas de
  formulario siguen en inglés («Add Timer», «Add Alarm»).
