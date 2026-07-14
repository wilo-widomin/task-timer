# 03 — Documentación Técnica

> **Detalles de implementación** para mantenedores: modelo de datos, APIs,
> persistencia, esquemas, pruebas, build/release y convenciones.

## 1. Stack tecnológico

| Aspecto | Valor |
|---|---|
| Lenguaje | Swift 5.9+ |
| Plataforma | macOS 13.0+ (Ventura) |
| UI | AppKit (`NSStatusItem`, `NSMenu`, `NSView`) + SwiftUI (`NSHostingController`) |
| Concurrencia | async/await, `@MainActor`, `actor`, `Sendable` |
| Persistencia | JSON (Codable), escritura atómica |
| Notificaciones | `UserNotifications` + `NSSound` |
| Testing | XCTest |
| Bundle ID | `com.menutimer.MenuTimer` |
| Versión actual | **1.5.3** (`MARKETING_VERSION`) |

## 2. Estructura del proyecto

```
menu-timer/
├── MenuTimer/
│   ├── App/
│   │   └── AppDelegate.swift            # @main, ciclo de vida, reconciliación
│   ├── Models/
│   │   ├── TimerItem.swift              # dominio + factories + Codable
│   │   └── PersistedStore.swift         # raíz serializable + schemaVersion
│   ├── Store/
│   │   └── TimerStore.swift             # @MainActor ObservableObject (MVVM)
│   ├── Engine/
│   │   ├── TickEngine.swift             # Timer 1 Hz único
│   │   └── FireScheduler.swift          # lógica pura de disparo
│   ├── Persistence/
│   │   ├── JSONPersistenceService.swift # actor, I/O atómico resiliente
│   │   └── FileLocations.swift          # resolución de rutas
│   ├── Services/
│   │   └── NotificationService.swift    # sonido + banner timeSensitive
│   ├── MenuUI/                          # AppKit (menubar)
│   │   ├── StatusItemController.swift
│   │   ├── MenuBuilder.swift
│   │   ├── MenuRefresher.swift
│   │   ├── TimerRowView.swift
│   │   └── BlockMenuItem.swift
│   ├── Forms/                           # SwiftUI
│   │   ├── WindowPresenter.swift
│   │   ├── AddTimerView.swift
│   │   ├── AddAlarmView.swift
│   │   ├── AddStopwatchView.swift
│   │   ├── AddPomodoroView.swift
│   │   ├── EditItemView.swift
│   │   ├── AboutView.swift
│   │   └── FormValidation.swift
│   └── Utilities/
│       ├── TimeFormatting.swift
│       └── AppInfo.swift
├── MenuTimerTests/                      # XCTest (ver §7)
├── MenuTimer.xcodeproj/
├── scripts/
│   └── build-release.sh                 # Release + .dmg firmado (no notarizado)
├── .githooks/                           # prepare-commit-msg: auto-bump semver
├── CLAUDE.md
└── docs/                                # ← esta documentación
```

## 3. Modelo de datos: `TimerItem`

`TimerItem` es un `struct` value type, `Identifiable, Codable, Equatable, Sendable`.

| Campo | Tipo | Aplica a | Descripción |
|---|---|---|---|
| `id` | `UUID` | todos | Identidad estable; también ID de la notificación. |
| `kind` | `ItemKind` | todos | `.timer` / `.alarm` / `.stopwatch` / `.pomodoro`. |
| `title` | `String` | todos | Texto mostrado y cuerpo de la notificación. |
| `createdAt` | `Date` | todos | Instante de creación. |
| `fireDate` | `Date` | timer/alarm/pomodoro | **Única fuente de verdad**. `remaining = fireDate - now`. |
| `configuredDuration` | `TimeInterval?` | timer/pomodoro | Duración original (segundos). |
| `state` | `ItemState` | todos | `.running` / `.paused` / `.finished`. |
| `didNotify` | `Bool` | (excepto stopwatch) | Garantiza notificar **una sola vez** por disparo (idempotencia). |
| `accumulatedElapsed` | `TimeInterval` | stopwatch | Segundos acumulados al pausar. |
| `lastStartedDate` | `Date?` | stopwatch | Último arranque/reanudación; `nil` en pausa. |
| `repeatInterval` | `TimeInterval?` | timer/alarm | Si está fijado, el item se repite cada N segundos. |
| `remainingCycles` | `Int?` | timer/alarm/pomodoro | Ciclos restantes (`nil` = infinito). |
| `breakDuration` | `TimeInterval` | pomodoro | Duración de la fase de descanso. |
| `isBreakPhase` | `Bool` | pomodoro | Fase actual (`false` = trabajo). |

### 3.1 Cálculos derivados (no almacenados)
```swift
func remaining(at now) -> TimeInterval   // fireDate - now; 0 si no-running o stopwatch
func hasFired(at now) -> Bool            // running && remaining <= 0 (stopwatch: siempre false)
func elapsed(at now) -> TimeInterval     // stopwatch: accumulated + (now - lastStartedDate)
var isRepeating: Bool                    // repeatInterval != nil && > 0
var isInfinite: Bool                     // isRepeating && remainingCycles == nil
var repeatLabel: String                  // "×N" / "∞" / ""
```

### 3.2 Factories estáticos
`TimerItem.timer(...)`, `.repeatingTimer(...)`, `.alarm(...)`, `.repeatingAlarm(...)`,
`.pomodoro(...)`, `.stopwatch(...)`. Todos aceptan `now: Date = Date()` inyectable
para tests.

## 4. Lógica de disparo: `FireScheduler`

`process(items: inout [TimerItem], now: Date) -> [TimerItem]` — **función pura**
(Struct `Sendable`). Recorre los items y transiciona los que acaban de disparar:

- **Cronómetros**: se ignoran (nunca disparan).
- **No repetidos** (timer/alarm): `state = .finished`, `didNotify = true`, se añade a `fired`.
- **Repetidos** (timer/alarm con `repeatInterval`):
  - `snapshot` con `didNotify = true` se añade a `fired` (para notificar este disparo).
  - Si `remainingCycles` finito y `<= 1` → `.finished` (último ciclo).
  - Si no: `fireDate = now + repeatInterval`, `remainingCycles -= 1` (si finito),
    `didNotify = false` para el siguiente ciclo.
- **Pomodoros**:
  - snapshot notificado.
  - Si estaba en **descanso**: si quedaba el último ciclo (`remainingCycles <= 1`) → `.finished`;
    si no, `remainingCycles -= 1`, vuelve a trabajo (`isBreakPhase = false`),
    `fireDate = now + configuredDuration`.
  - Si estaba en **trabajo**: pasa a descanso (`isBreakPhase = true`),
    `fireDate = now + breakDuration`.

> La combinación `hasFired(at:) && !didNotify` es lo que garantiza idempotencia
> frente a ticks repetidos o relanzamientos.

## 5. Persistencia

### 5.1 Ruta
`~/Library/Application Support/MenuTimer/store.json` (resuelto por `FileLocations`,
inyectable para tests vía `supportDirectory`).

### 5.2 Formato (`PersistedStore`)
```json
{
  "schemaVersion": 4,
  "items": [ { "id": "...", "kind": "timer", "title": "...", ... } ]
}
```
- Codificación: `JSONEncoder` con `.prettyPrinted`, `.sortedKeys`, fechas **ISO 8601**.
- Decodificación: `JSONDecoder` con `.iso8601`.

### 5.3 Esquemas y migraciones
`PersistedStore.currentSchemaVersion = 4`. La migración es **implícita y
tolerante**: `TimerItem.init(from:)` usa `decodeIfPresent` con defaults para los
campos añadidos en cada versión:

| Schema | Añade |
|---|---|
| 1 | Base (`TimerItem` original). |
| 2 | `accumulatedElapsed`, `lastStartedDate` (cronómetros). Default `0` / `nil`. |
| 3 | `repeatInterval`, `remainingCycles` (repetición/snooze). Default `nil`. |
| 4 | `.pomodoro` kind, `breakDuration`, `isBreakPhase`. Default `0` / `false`. |

> No hay paso de migración explícito: leer un store viejo y volver a guardarlo
> lo deja en la versión actual automáticamente (los defaults se materializan).

### 5.4 Resiliencia
- `load()`/`loadSynchronously()` devuelven `PersistedStore.empty` si el fichero
  falta o no decodifica (corrupción) — **la app siempre arranca**.
- `save()` crea el directorio si no existe y escribe con `Data.write(options: .atomic)`
  → no puede quedar un fichero a medias.
- Las escrituras se serializan en un `actor` (`JSONPersistenceService`) → nunca se
  intercalan escrituras concurrentes.
- Errores de escritura se loguean (`NSLog`) y se tragan — un fallo transitorio no
  crashea la UI.

### 5.5 Protocolo
```swift
public protocol PersistenceService: Sendable {
    func load() async -> PersistedStore
    func save(_ store: PersistedStore) async throws
}
```
Permite inyectar un backend falso en tests (`TestDoubles.swift`).

## 6. Store: API pública (`TimerStore`)

`@MainActor public final class TimerStore: ObservableObject`
- `@Published public private(set) var items: [TimerItem]`

**Carga / reconciliación**
- `adoptInitialState(_:)` — adopta estado ya cargado sin persistir (arranque sincrónico).
- `load(now:)` async — carga + reconcile.
- `reconcile(now:)` — un tick (usado en arranque, activate y wake).

**Mutaciones** (todas persisten)
- `addTimer(title:duration:now:)`, `addRepeatingTimer(...)` → `@discardableResult TimerItem`
- `addAlarm(...)`, `addRepeatingAlarm(...)` → `TimerItem`
- `addStopwatch(title:now:)` → `TimerItem`
- `addPomodoro(title:workDuration:breakDuration:cycles:now:)` → `TimerItem`
- `pauseStopwatch(id:now:)`, `continueStopwatch(id:now:)`
- `updateItemTitle(id:title:)`
- `updateTimer(...)`, `updateAlarm(...)`, `updatePomodoro(...)` (recalculan `fireDate` desde `now`)
- `remove(id:)`, `clearFinished()`

**Tick**
- `tick(now:)` — delega en `FireScheduler`; si algo disparó → notifica + persiste;
  no-op en caso contrario (no muta `@Published`).

**Orden**: `sorted(_:)` agrupa por `sortGroup`: 0=timer/alarm running, 1=pomodoro,
2=stopwatch, 3=finished; dentro de cada grupo ordena por `fireDate` (y pomodoros
por fase trabajo→descanso→finished).

## 7. Pruebas (XCTest)

Cobertura orientada a **lógica pura** y **integración de store**:

| Fichero | Qué cubre |
|---|---|
| `TimerItemTests` | Factories, `remaining`, `hasFired`, idempotencia, caso `remaining` negativo pre-reconcile. |
| `FireSchedulerTests` | Disparo único, idempotencia entre ticks, disparos múltiples. |
| `ReconciliationTests` | Disparo tras salto temporal, no doble-notificación. |
| `TimerStoreTests` | add/remove, orden por fireDate, tick dispara y notifica, tick no-op, `load` reconcilia y no re-notifica, mutaciones persisten. |
| `JSONPersistenceServiceTests` | Fichero ausente → empty, round-trip, corrupción → empty, preservación de schemaVersion, creación de directorio, escritura atómica. |
| `MenuBuilderTests` | Estado vacío, cabeceras por tipo, agrupación, closure de delete, limpieza previa. |
| `FormValidationTests` | Conversión de duración, clamp de negativos, trim de título, validez de timer/alarm. |
| `TimeFormattingTests` | Countdown bajo/sobre 1 h, clamp negativo, redondeo hacia arriba, `durationLabel`. |
| `TestDoubles` | Fakes de `PersistenceService` / `NotificationServing`. |

Ejecución: `⌘U` en Xcode.

## 8. Concurrencia: contrato de aislamiento

- **`@MainActor`**: `AppDelegate`, `TimerStore`, `TickEngine`, `StatusItemController`,
  `MenuBuilder`, `TimerRowView`, `MenuRefresher`, `BlockMenuItem`, `WindowPresenter`,
  `NotificationService` y su protocolo `NotificationServing`.
- **`actor`**: `JSONPersistenceService` (I/O serializado en background).
- **`Sendable`** (puros, cruzan actores): `TimerItem`, `PersistedStore`, `FireScheduler`, `FileLocations`.
- `JSONPersistenceService.loadSynchronously()` es `nonisolated` (lectura pequeña y
  segura en el arranque del hilo principal); accede solo al campo `nonisolated let locations`.

## 9. Notificaciones: detalles técnicos

- **Sonido**: reproducido con `NSSound(contentsOf:byReference:)` desde el bundle.
  `timer_sound.wav` (1 vez), `alarm_sound.wav` (3 veces vía `NSSoundDelegate`
  re-encolando `play()`). Los sonidos activos se retienen en `activeSounds` hasta
  terminar (ARC no los libera a mitad).
- **Banner**: `UNMutableNotificationContent` con `sound = nil` (el sonido va aparte)
  e `interruptionLevel = .timeSensitive` (persistente). `trigger: nil` = inmediato.
  `identifier = item.id.uuidString`.
- **Delegate**: `willPresent` devuelve `[.banner, .list]` para que el banner aparezca
  incluso con la app en primer plano.
- **Autorización**: `requestAuthorization([.alert, .sound])` sin bloquear el arranque;
  fallos no fatales (solo `NSLog`).

## 10. Build y release

### Desarrollo
```sh
open MenuTimer.xcodeproj   # scheme MenuTimer; ⌘R run, ⌘U tests
```

### Release (script `scripts/build-release.sh`)
- Compila `Release` y empaqueta `dist/MenuTimer-<version>.dmg`.
- **Firma manual** con el cert “Apple Development” del llavero (hay que pasar el
  **hash SHA-1** exacto del cert, porque `xcodebuild` traduce el nombre y no lo
  encuentra). Sobreescribible con `DEVELOPMENT_TEAM` / `CODE_SIGN_IDENTITY`.
- **No usa sandbox** ni capabilities que requieran provisioning profile → no hace
  falta cuenta Apple ID en Xcode ni **notarización**.
- Distribución: repartir a usuarios de confianza (la primera vez deben abrir con
  clic derecho → Abrir, al no estar notarizada).

## 11. Gestión de versiones (CRÍTICO)

- La versión (`MARKETING_VERSION`) vive en `MenuTimer.xcodeproj/project.pbxproj`
  en **4 sitios** (Debug + Release × app target + test target). Actualizar los 4.
- **Regla**: todo commit que toque código de producción **debe** subir la versión.
- **Semver**: `fix:` → patch, `feat:` → minor, `feat!:` → major; chore/docs/refactor → sin bump.
- **Auto-bump**: el hook `prepare-commit-msg` en `.githooks/` sube la versión
  automáticamente según el mensaje del commit. Activar una vez:
  ```sh
  git config core.hooksPath .githooks
  ```

## 12. Convenciones de código

- Comentarios estilo doc (`///`) en todas las entidades públicas y en las decisiones
  no obvias (p. ej. por qué se usa AppKit en el menú, por qué `NSSound` en vez de
  `UNNotificationSound`, por qué `mouseDown` llama closures en vez de reenviar el evento).
- Mutaciones del store siempre van seguidas de `persist()`.
- Preferencia por **inyección de `now: Date`** en toda función de tiempo → tests deterministas.
- `NSLog` para fallos no fatales (persistencia, notificaciones, carga de sonido).
- `AppInfo` lee **del bundle** (nunca hardcodea) la versión, con fallback al
  `infoDictionary` crudo si el lookup localizado falla.

## 13. Puntos de extensión comunes

| Si quieres añadir… | Dónde tocar |
|---|---|
| Un nuevo tipo de item | `ItemKind` + factory en `TimerItem` + rama en `FireScheduler.process` + sección en `MenuBuilder` + formulario + rama en `WindowPresenter.applyEdit`. Subir `schemaVersion` si añades campos. |
| Un nuevo campo persistido | Añadir a `TimerItem`, codificar con default vía `decodeIfPresent`, subir `currentSchemaVersion`, documentar la migración en [§5.3](#53-esquemas-y-migraciones). |
| Una nueva acción de menú | `MenuBuilder.Actions` + `BlockMenuItem` + closure en `StatusItemController`. |
| Cambiar el sonido | Reemplazar `timer_sound.wav` / `alarm_sound.wav` en el bundle, o ajustar `alarmRepeatCount`. |
