---
dominio: items
actualizado: 2026-08-02
archivos:
  - Sources/MenuTimerKit/Models/TimerItem.swift
  - Sources/MenuTimerKit/Models/PersistedStore.swift
  - Sources/MenuTimerKit/Store/TimerStore.swift
  - MenuTimer/Models/TimerItem.swift
  - MenuTimer/Store/TimerStore.swift
depende_de: [disparo/_dominio, persistencia/_dominio]
---

# Items

Todo lo que la app gestiona es un `TimerItem`: temporizador, alarma, cronómetro o
pomodoro. `TimerStore` es la única fuente de verdad y el único sitio que muta la lista.

## Entidades

- `TimerItem` (`Sources/MenuTimerKit/Models/TimerItem.swift`)
  - `kind: ItemKind` — `.timer`, `.alarm`, `.stopwatch`, `.pomodoro`.
  - `state: ItemState` — `.running`, `.paused`, `.finished`. `.paused` es **solo de
    cronómetros**.
  - `fireDate` — instante absoluto en que salta. Para timers y alarmas es la verdad;
    lo restante **se deriva** (`fireDate - now`), nunca se almacena.
  - `configuredDuration` — solo timer y pomodoro (en pomodoro es la fase de trabajo).
  - `breakDuration` + `isBreakPhase` — fase actual del pomodoro.
  - `repeatInterval` + `remainingCycles` — repetición; `remainingCycles == nil`
    significa infinito, no cero.
  - `didNotify` — evita notificar dos veces el mismo disparo. Ver `disparo/`.
  - `accumulatedElapsed` + `lastStartedDate` — de donde sale el tiempo del cronómetro.
- `TimerStore` (`Store/TimerStore.swift`) — `@Published private(set) var items`.
  Mutadores: `addTimer`, `addRepeatingTimer`, `addAlarm`, `addRepeatingAlarm`,
  `addStopwatch`, `addPomodoro`, `pauseStopwatch`, `continueStopwatch`,
  `updateItemTitle`, `updateTimer`, `updateAlarm`, `updatePomodoro`, `remove`,
  `clearFinished`.

## Invariantes

- `items` es `private(set)`: fuera del store nadie muta la lista.
- Todo mutador reordena con `sorted(_:)` y persiste. No hay guardado manual.
- El orden es por grupos, no alfabético ni de creación:
  `0` timer/alarma en marcha → `1` pomodoros (trabajo antes que descanso) →
  `2` cronómetros → `3` timers/alarmas terminados. Dentro de cada grupo, por
  `fireDate` más próximo.
- Los cronómetros nunca pasan a `.finished`: cuentan hacia arriba sin límite.

## Trampas

- **Editar un timer reinicia la cuenta atrás.** `updateTimer` recalcula
  `fireDate = now + duration` y pone `state = .running`, `didNotify = false`. No
  conserva el tiempo restante; si alguien quiere eso, hay que cambiar el mutador.
- `updatePomodoro` sí respeta la fase de descanso en curso: solo recalcula el
  `fireDate` si está en fase de trabajo.
- Los mutadores validan en silencio: `updateTimer` con `duration <= 0`, o
  `updateItemTitle` con título vacío, **no hacen nada y no avisan**.
- Cada mutador comprueba el `kind`: `updateAlarm` sobre un timer es un no-op.
- `remainingCycles == nil` es «infinito». Tratarlo como 0 rompe las repeticiones.
