---
dominio: interfaz
accion: listado-widomin
actualizado: 2026-08-02
archivos:
  - Sources/MenuTimerKit/Views/MenuTimerMainView.swift
  - Sources/MenuTimerKit/Views/MenuTimerRow.swift
depende_de: [items/_dominio, formularios/_dominio]
---

# Listado de Widomin

La vista que se ve dentro del popover de Widomin: items agrupados por tipo, botonera
de creación abajo, y acciones de editar y eliminar por fila.

## Estructura

1. Lista vacía → icono y «Sin temporizadores» centrados.
2. Si hay items, `ScrollView` + `LazyVStack` con una sección por tipo, en orden fijo:
   Temporizadores → Alarmas → Pomodoros → Cronómetros. Las secciones vacías se omiten,
   así el orden nunca baila según lo que el usuario cree primero.
3. `Divider` y botonera: Timer, Alarma, Crono, Pomodoro.

## Archivos

- `MenuTimerMainView.swift` — secciones (`KindSection`), cabeceras, botonera, y
  `applyEdit(store:item:values:)`, que enruta los `EditValues` del formulario al
  mutador correcto del store según el `kind`.
- `MenuTimerRow.swift` — la fila: icono coloreado por estado, título, subtítulo,
  tiempo monoespaciado y los botones de acción.

## Reglas

- La lista va envuelta en `TimelineView(.periodic(from: .now, by: 1))` y las filas
  reciben `context.date`, **no** `Date()`. Es lo único que mantiene las cuentas atrás
  vivas: el store no notifica cambios mientras no venza nada.

- El tipo auxiliar de sección se llama `KindSection`, **no `Section`**: dentro del
  mismo tipo, `Section` resolvería al struct propio en vez de a `SwiftUI.Section` y el
  `ForEach` no compila.
- Las cabeceras son texto en color de acento **sin fondo**. Dentro de un popover
  translúcido cualquier material se ve como una banda lavada, sobre todo con la
  ventana sin foco.
- Los botones de editar/eliminar aparecen con `onHover` pero **mantienen su hueco**
  (`.opacity(0)`, no se quitan del layout): si no, la columna de tiempo se desplaza al
  pasar el ratón.
- Cada formulario de edición se presenta con id `"edit-<uuid del item>"`, distinto por
  item, para poder tener varios abiertos sin que se pisen.

## Trampas

- `applyEdit` recurre a valores por defecto cuando el formulario no trae dato: 300 s
  para timer y 1500 s para pomodoro. Vienen del `WindowPresenter` de la app standalone.
- Los cronómetros solo aceptan cambio de título; el resto de `EditValues` no les aplica.
- Editar un temporizador **reinicia su cuenta atrás** — es cosa de `updateTimer`, no de
  esta vista. Ver `items/_dominio.md`.
