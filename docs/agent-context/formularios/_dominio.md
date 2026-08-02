---
dominio: formularios
actualizado: 2026-08-02
archivos:
  - Sources/MenuTimerKit/Forms/WindowPresenter.swift
  - Sources/MenuTimerKit/Forms/AddTimerView.swift
  - Sources/MenuTimerKit/Forms/AddAlarmView.swift
  - Sources/MenuTimerKit/Forms/AddStopwatchView.swift
  - Sources/MenuTimerKit/Forms/AddPomodoroView.swift
  - Sources/MenuTimerKit/Forms/EditItemView.swift
  - Sources/MenuTimerKit/Forms/FormValidation.swift
  - MenuTimer/Forms/WindowPresenter.swift
depende_de: [items/_dominio]
---

# Formularios

Las ventanas de crear y editar. Son vistas SwiftUI puras: **no tocan el store**, solo
devuelven valores por closure. Quien las presenta decide qué hacer con ellos.

## Piezas

- `AddTimerView`, `AddAlarmView`, `AddStopwatchView`, `AddPomodoroView` — cada una con
  `onSubmit` (los valores) y `onCancel`.
- `EditItemView(item:onSave:onCancel:)` — formulario único que se adapta al `kind` y
  devuelve un `EditValues` con los campos de todos los tipos, opcionales.
- `FormValidation` — `duration(hours:minutes:)`, `normalizedTitle(_:)`,
  `isValidTimer(...)`, `isValidAlarm(...)`. Es lo único con tests directos.
- `WindowPresenter` — abre cada formulario en su `NSWindow`.

## Dos WindowPresenter con el mismo nombre y distinta API

| Copia | API | Quién la usa |
|---|---|---|
| `Sources/MenuTimerKit/Forms/` | genérica: `present(id:title:root:)`, `close(id:)`, `closeAll()`; `init()` sin argumentos | Widomin |
| `MenuTimer/Forms/` | específica: `showAddTimer()`, `showEdit(item:)`, `showAbout()`…; `init(store:)` | app standalone |

La del paquete no conoce el store: recibe la vista ya construida. La de la app lo
tiene dentro y aplica los cambios ella misma. **No son intercambiables**; al portar
algo entre ambas hay que reescribir la llamada, no copiarla.

## Invariantes

- Una ventana por `id`: volver a presentar el mismo id trae al frente la existente en
  vez de abrir otra.
- `isReleasedWhenClosed = false` y la ventana guardada en el diccionario. Sin esa
  referencia fuerte, AppKit la libera y la app **casca al cerrar el formulario**.
- `windowWillClose` limpia la entrada del diccionario; si no, el id quedaría ocupado
  por una ventana muerta y no se podría reabrir.
- `bringToFront` llama a `NSApp.activate(ignoringOtherApps:)`: siendo `LSUIElement`,
  sin eso la ventana sale sin foco de teclado.

## Trampas

- `EditValues` trae los campos de **todos** los tipos como opcionales. Quien lo consume
  debe mirar el `kind` del item y usar solo los suyos; ver `applyEdit` en
  `interfaz/listado-widomin.md`.
- Los formularios no validan al guardar: quien recibe `onSubmit` es responsable. Los
  mutadores del store descartan en silencio lo inválido.
