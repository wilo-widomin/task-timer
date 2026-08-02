---
dominio: notificaciones
actualizado: 2026-08-02
archivos:
  - Sources/MenuTimerKit/Services/NotificationService.swift
  - MenuTimer/Services/NotificationService.swift
  - MenuTimer/Resources/alarm_sound.wav
  - MenuTimer/Resources/timer_sound.wav
depende_de: [disparo/_dominio]
---

# Notificaciones

Avisar cuando un item salta: sonido más notificación del sistema. Lo dispara
`TimerStore.tick` con los items que devuelve el scheduler.

## Piezas

- `NotificationDispatching` — protocolo con `postNotification(for:)` y
  `requestAuthorization()`. Permite inyectar un doble en tests.
- `NotificationService` — implementación sobre `UNUserNotificationCenter` y `NSSound`.

## Decisiones que parecen errores y no lo son

- **El sonido no lo pone la notificación, lo pone la app.** `content.sound = nil` y la
  reproducción va por `NSSound`. Los sonidos personalizados de `UNNotificationSound`
  son poco fiables en macOS: el sistema los ignora a menudo y cae al sonido por
  defecto. Contrapartida asumida: al sonar por nuestra cuenta, **se salta No Molestar
  y los modos de Concentración**. Para un despertador es lo que se quiere.
- `interruptionLevel = .timeSensitive` para que la alerta se quede en pantalla en vez
  de desvanecerse. `.critical` sería más insistente pero exige un entitlement que
  Apple aprueba caso por caso.
- La alarma suena **3 veces** (`alarmRepeatCount`); el temporizador, una. El
  encadenado de repeticiones se lleva con `NSSoundDelegate`.

## Trampas

- Los sonidos que están en marcha se guardan en una colección propia: sin esa
  referencia fuerte, ARC libera el `NSSound` a medio reproducir y el aviso se corta.
- El identificador de la notificación es el `id` del item. Dos disparos del mismo item
  repetitivo reutilizan identificador — el sistema reemplaza la notificación anterior
  en lugar de apilarla.
- `requestAuthorization()` es lo único genuinamente asíncrono del arranque. La interfaz
  no depende de ello, así que se lanza en un `Task` aparte y no se espera.
- Los `.wav` están **por duplicado**: en `MenuTimer/Resources/` para la app y en
  `Sources/MenuTimerKit/Resources/` para el paquete, que los declara con
  `resources: [.process("Resources")]` en `Package.swift`.
- La copia del paquete resuelve con `Bundle.module` y la de la app con `Bundle.main`:
  es la **única divergencia intencionada** entre ambas copias, porque `Bundle.module`
  no existe fuera de un target SPM. Usar `Bundle.main` desde el paquete deja al
  anfitrión sin sonido, en silencio y sin error.
