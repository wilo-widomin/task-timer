# 02 — Documentación de Arquitectura

> **Cómo está estructurada Menu Timer**. Componentes, responsabilidades y
> flujos de datos. Para desarrolladores que se incorporan al proyecto.

## 1. Principios de diseño

| Principio | Aplicación |
|---|---|
| **`fireDate` como única fuente de verdad** | El tiempo restante se *deriva* (`fireDate - now`), nunca se almacena ni se decrementa. Robusto ante sleep, reboot y deriva de reloj. |
| **Un único latido** | Un solo `Timer` a 1 Hz (`TickEngine`) refresca **todos** los items. No hay un timer por item → CPU/energía mínimos y estado coherente. |
| **MVVM con store único** | `TimerStore` (`ObservableObject`) es la única fuente de verdad observable; alimenta el menú. |
| **Separación de lógica pura** | Las transiciones de estado (`FireScheduler`), el formateo (`TimeFormatting`) y la validación (`FormValidation`) son **puras y testeables**, sin dependencias de UI ni notificaciones. |
| **UI híbrida AppKit + SwiftUI** | AppKit para el menubar (más fiable dentro de `NSMenu`); SwiftUI para formularios y About. |
| **Persistencia atómica y resiliente** | Escrituras atómicas fuera del hilo principal; un fichero corrupto/inexistente **degrada a store vacío**, nunca crashea. |

## 2. Vista de alto nivel

```
@main AppDelegate
   │  (ciclo de vida, reconciliación, wake-from-sleep)
   ├──> TimerStore  ──┐  (ObservableObject, @MainActor, única fuente de verdad)
   │       │          │
   │       ├──> JSONPersistenceService (actor, I/O en background, atómico)
   │       ├──> FireScheduler           (lógica pura de disparo)
   │       └──> NotificationService     (sonido + banner)
   │
   ├──> StatusItemController ──> MenuBuilder ──> TimerRowView (AppKit)
   │        │                                       ▲
   │        └──> MenuRefresher (refresca contadores in-situ cada segundo)
   │
   ├──> WindowPresenter ──> [AddTimerView, AddAlarmView, AddStopwatchView,
   │                          AddPomodoroView, EditItemView, AboutView] (SwiftUI)
   │
   └──> TickEngine (1 Hz) ──> store.tick(now:)  +  statusController.tick(now:)
```

## 3. Componentes y responsabilidades

### 3.1 Capa de App / ciclo de vida
**`AppDelegate`** (`MenuTimer/App/AppDelegate.swift`)
- Entry point con `@main` y `@MainActor`; arranca `NSApplication` manualmente con
  política `.accessory` (sin Dock, sin menú de app).
- En `applicationDidFinishLaunching`: crea el store (con carga **sincrónica** para
  evitar parpadeo de menú vacío), hace `reconcile(now:)`, construye el
  `StatusItemController`, el `WindowPresenter`, arranca el `TickEngine` y pide
  permiso de notificaciones sin bloquear.
- **Reconciliación de deriva** en tres puntos: arranque, `applicationDidBecomeActive`
  y al despertar del sistema (`NSWorkspace.didWakeNotification`). En todos se llama
  a `store.reconcile(now:)` para recuperar el tiempo real perdido.

### 3.2 Capa de dominio / modelos
**`TimerItem`** (`MenuTimer/Models/TimerItem.swift`) — ver [técnica §3](./03-tecnica.md#3-modelo-de-datos-timeritem).
Value type `Codable` que representa un item. Define `ItemKind` (.timer/.alarm/.stopwatch/.pomodoro)
e `ItemState` (.running/.paused/.finished), y los **cálculos derivados**:
`remaining(at:)`, `hasFired(at:)`, `elapsed(at:)`, más factories estáticos.

**`PersistedStore`** (`MenuTimer/Models/PersistedStore.swift`) — raíz serializable:
`{ schemaVersion, items: [TimerItem] }`. El `schemaVersion` (actual **4**) habilita
migraciones hacia adelante.

### 3.3 Capa de store / view-model
**`TimerStore`** (`MenuTimer/Store/TimerStore.swift`) — `@MainActor ObservableObject`.
- `@Published private(set) var items` alimenta el menú.
- Operaciones: `addTimer/addAlarm/addStopwatch/addPomodoro` (y variantes
  `addRepeating…`), `pauseStopwatch`, `continueStopwatch`, `updateTimer/updateAlarm/updatePomodoro/updateItemTitle`,
  `remove`, `clearFinished`, `adoptInitialState`, `load`, `reconcile`, `tick`.
- `tick(now:)` delega la lógica de disparo al `FireScheduler` y, si algo disparó,
  publica notificaciones y persiste. **No toca estado `@Published` si nada dispara**
  (el refresco del contador por segundo lo hace `MenuRefresher`, aparte).
- Mantiene un **orden de visualización** coherente (`sorted(_:)`).

### 3.4 Capa de motor / scheduling
**`TickEngine`** (`MenuTimer/Engine/TickEngine.swift`) — `@MainActor`. Un `Timer`
repetitivo a 1 s con `tolerance = 0.1` (ahorro de energía), añadido al `RunLoop`
en modo `.common` para que **siga disparando mientras se sigue un menú** (que corre
el run loop en modo event-tracking). `start()` dispara una vez inmediatamente.

**`FireScheduler`** (`MenuTimer/Engine/FireScheduler.swift`) — `struct Sendable`,
**pura**. `process(items:&, now:)` detecta qué items acaban de disparar y los
transiciona. Lógica clave:
- **Idempotencia**: la bandera `didNotify` garantiza que un disparo se reporta **una sola vez**, incluso entre ticks repetidos o relanzamientos.
- **No-repetidos**: pasan a `.finished`, `didNotify = true`.
- **Repetidos**: avanzan `fireDate += repeatInterval`, decrementan `remainingCycles`
  (si finito) y, al llegar al último ciclo, terminan.
- **Pomodoros**: alternan `isBreakPhase` y recalculan `fireDate` con la duración
  de la siguiente fase.
- Los **cronómetros nunca disparan**.

### 3.5 Capa de UI de menubar (AppKit)
**`StatusItemController`** (`MenuTimer/MenuUI/StatusItemController.swift`) — posee
el `NSStatusItem` y el `NSMenu`. Es `NSMenuDelegate`:
- `menuNeedsUpdate(_:)` → llama a `MenuBuilder.populate(...)` (reconstruye el menú).
- Lleva `isMenuOpen` para que `tick(now:)` solo refresque contadores con el menú abierto.
- Enruta acciones (add/edit/about/quit/delete/togglePause) vía closures al `WindowPresenter`/store.
- **`confirmDelete`**: cancela el tracking del menú antes de actuar (evita que el
  `mouse-up` pendiente caiga en otro ítem) y **difiere el trabajo al siguiente
  ciclo del run loop**. Los items terminados se borran sin confirmación.

**`MenuBuilder`** (`MenuTimer/MenuUI/MenuBuilder.swift`) — reconstruye el menú
*in-place* (mismo objeto `NSMenu`, no se reemplaza). Estructura: comandos fijos
(Add …) + sección dinámica agrupada por tipo con cabeceras + footer (About/Quit).

**`TimerRowView`** (`MenuTimer/MenuUI/TimerRowView.swift`) — vista AppKit usada
como `NSMenuItem.view`. Layout `[título / subtítulo] … [tiempo] [⏸] [🗑]`.
- El título es clickeable (cursor mano) → dispara `onEdit`.
- El botón de acción (⏸/▶) solo aparece para cronómetros, y se **inserta/quita**
  del `NSStackView` en lugar de ocultarse (evita un bug de espaciado residual).
- **Gestión de eventos crítica**: `mouseDown(with:)` llama directamente a los
  closures en vez de reenviar el evento a los subviews, para evitar una
  **recursión infinita** (fue la causa de un crash real al borrar con el menú
  abierto — ver histórico de commits).

**`MenuRefresher`** (`MenuTimer/MenuUI/MenuRefresher.swift`) — actualiza **solo el
texto** de las filas visibles cada segundo (barato), sin reconstruir el menú.

**`BlockMenuItem`** (`MenuTimer/MenuUI/BlockMenuItem.swift`) — `NSMenuItem` que
ejecuta un closure al seleccionarse; evita el plumbing `target/action`.

### 3.6 Capa de UI de formularios (SwiftUI)
**`WindowPresenter`** (`MenuTimer/Forms/WindowPresenter.swift`) — `@MainActor`,
`NSWindowDelegate`. Presenta cada formulario y About en un `NSWindow` ligero
(`NSHostingController`), **singleton por ventana** (re-invocar = traer al frente).
Recopila los valores del formulario y los traduce a llamadas de store según el
`kind` del item.

**Formularios**: `AddTimerView`, `AddAlarmView`, `AddStopwatchView`, `AddPomodoroView`,
`EditItemView`, `AboutView`. Validación compartida vía `FormValidation`.

### 3.7 Capa de servicios
**`NotificationService`** (`MenuTimer/Services/NotificationService.swift`) —
`@MainActor`. Reproduce el sonido **directamente con `NSSound`** (los sonidos
`UNNotificationSound` personalizados son poco fiables en macOS) y publica una
notificación **silenciosa** (`content.sound = nil`) con `interruptionLevel = .timeSensitive`.
El sonido de alarma se repite 3 veces mediante `NSSoundDelegate`. Es también
delegate del `UNUserNotificationCenter` para mostrar el banner aunque la app esté
en primer plano.

**`JSONPersistenceService`** (`MenuTimer/Persistence/JSONPersistenceService.swift`) —
`actor` que serializa todo el I/O de disco en un executor de fondo. Carga
resiliente (`decodeIfPresent` → store vacío ante corrupción), escritura atómica.
Expone `loadSynchronously()` `nonisolated` para el arranque.

**`FileLocations`** (`MenuTimer/Persistence/FileLocations.swift`) — resuelve la
ruta `~/Library/Application Support/MenuTimer/store.json` (inyectable para tests).

### 3.8 Utilidades
**`TimeFormatting`**, **`FormValidation`**, **`AppInfo`** — funciones puras/stateless.

## 4. Flujos de datos principales

### 4.1 Flujo del tick (cada segundo)
```
TickEngine (1 Hz)
   → store.tick(now:)           // FireScheduler procesa disparos; notifica y persiste
   → statusController.tick(now) // si menú abierto: MenuRefresher actualiza texto de filas
```
- Si **nada dispara**, `tick` es un no-op que no muta `@Published`.
- El **refresco visual del contador** (MM:SS…) es independiente del disparo:
  lo hace `MenuRefresher` sobre las vistas existentes.

### 4.2 Flujo de creación (Add Timer)
```
Usuario: Add Timer…
 → StatusItemController.onAddTimer
 → WindowPresenter.showAddTimer()  (ventana singleton, AddTimerView)
 → onSubmit: store.addTimer(...)   (o addRepeatingTimer)
 → store: items = sorted(...); persist() (actor, atómico)
 → @Published items cambia → menuNeedsUpdate reconstruye el menú
```

### 4.3 Flujo de disparo (item llega a fireDate)
```
TickEngine → store.tick(now:)
 → FireScheduler.process(items:&, now:)
    - marca didNotify, transiciona (.finished o reset de repetido/pomodoro)
    - devuelve [items que recién dispararon]
 → por cada item: notificationService.postNotification(for:)
    - playSound (NSSound), UNNotificationRequest silenciosa timeSensitive
 → persist()
```

### 4.4 Flujo de reconciliación (arranque / activate / wake)
```
AppDelegate.reconcile(now:) → store.reconcile(now:) → tick(now:)
 // dispara todo lo vencido durante el tiempo muerto, sin re-notificar lo ya notificado
```

## 5. Modelo de concurrencia

- **Todo el acceso al store es `@MainActor`**: las mutaciones ocurren en el hilo
  principal; la persistencia se despacha a un `actor` de fondo.
- `TickEngine` usa `MainActor.assumeIsolated` dentro del callback del `Timer`
  (los callbacks de `Timer` llegan al run loop principal).
- `FireScheduler` y `TimerItem` son `Sendable` → pueden cruzar la frontera de
  actores sin problemas.

## 6. Decisiones de diseño destacadas

| Decisión | Por qué |
|---|---|
| **AppKit para el menú, no SwiftUI** | Las vistas personalizadas dentro de `NSMenu` son mucho más estables con AppKit; además permite mutar solo la etiqueta del contador cada segundo sin reconstruir. |
| **Sonido vía `NSSound`, no `UNNotificationSound`** | Los sonidos personalizados del bundle son poco fiables en macOS. Contrapartida asumida: se ignora No Molestar (aceptable para un temporizador). |
| **Carga sincrónica en el arranque** | Evita el “flash” de menú vacío durante la carga asíncrona; el fichero es pequeño. |
| **Singleton por ventana** | Re-abrir un formulario no crea duplicados; solo trae la existente al frente. |
| **`schemaVersion` + `decodeIfPresent`** | Migraciones hacia adelante sin romper datos antiguos (campos nuevos con defaults). |

## 7. Errores conocidos / lecciones (del histórico de commits)

- **Recursión infinita al borrar desde el menú contextual**: se evita llamando a
  los closures directamente en `mouseDown` en vez de reenviar el evento a los
  subviews (que re-rutearía vía `forwardMethod`).
- **Bumps de versión olvidados**: cualquier commit que toque código de producción
  **debe** subir `MARKETING_VERSION` (4 sitios del `pbxproj`). Hay un hook
  `prepare-commit-msg` en `.githooks/` que lo automatiza por semver.
