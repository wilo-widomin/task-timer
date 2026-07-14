# 01 — Documentación Funcional

> **Qué hace Menu Timer** desde el punto de vista del usuario.
> No asume conocimiento del código.

## 1. Propósito

Menu Timer es una aplicación de **barra de menús** para macOS. Vive como un
icono en la barra superior del sistema y permite crear **temporizadores de
cuenta atrás**, **alarmas a hora fija**, **cronómetros** y **pomodoros**, todo
sin ocupar el Dock ni abrir ventanas permanentes.

Características clave desde la perspectiva del usuario:

- **Sin presencia en el Dock**: es una app “agente” (`LSUIElement`). Solo aparece
  el icono en la barra de menús.
- **Estado persistente**: los items sobreviven a cerrar y reabrir la app (e
  incluso a reiniciar el equipo). Si una alarma debía sonar mientras la app
  estaba cerrada, se reconcilia al arrancar.
- **Notificaciones**: cuando un temporizador o alarma “dispara”, suena un sonido
  y aparece un banner, **una sola vez** por disparo (no se repite aunque el item
  siga “vencido”).
- **Funciona tras suspensiones (sleep) y cambios de hora**: al despertar el
  equipo o reactivar la app, se recalcula el estado contra el reloj real.

## 2. Tipos de items

La app gestiona cuatro tipos de items:

### 2.1 Temporizador (Timer)
Cuenta atrás a partir de una **duración** (horas + minutos). Se configura el
tiempo y, al llegar a cero, dispara. El tiempo restante se muestra en formato
`MM:SS`, `H:MM:SS` o `D:H:MM:SS` según la magnitud.

### 2.2 Alarma (Alarm)
Se dispara a una **fecha/hora absoluta** (por ejemplo “14:30” o “mañana 09:00”).
A diferencia del temporizador, se define por el instante objetivo, no por una
duración.

### 2.3 Cronómetro (Stopwatch)
Cuenta **el tiempo transcurrido hacia arriba**. Se puede pausar y reanudar. Los
cronómetros nunca “disparan” ni generan notificaciones.

### 2.4 Pomodoro
Alterna entre **fases de trabajo** y **fases de descanso**. El usuario define la
duración del trabajo, la del descanso y cuántos ciclos completar (`nil` = infinito).
Al terminar una fase, el pomodoro cambia a la siguiente automáticamente (trabajo
→ descanso → trabajo → descanso …) y notifica en cada cambio de fase, hasta
agotar los ciclos.

### 2.5 Repetición (común a timers y alarmas)
Los temporizadores y las alarmas pueden **repetirse**:

- **Temporizador repetido**: tras dispararse, reinicia la cuenta atrás por sí solo
  (estilo pomodoro clásico).
- **Alarma con snooze**: tras dispararse, vuelve a sonar cada N segundos un número
  de veces configurado.

Cada item repetido muestra una etiqueta de ciclos (`×4` para finito, `∞` para
infinito) junto a su configuración.

## 3. Casos de uso

### CU-1: Crear un temporizador
1. El usuario abre el menú desde el icono de la barra.
2. Selecciona **Add Timer…** (atajo `⌘T` dentro del menú / tecla `T`).
3. Rellena título, horas y minutos. Opcionalmente activa la repetición y el nº de ciclos.
4. Pulsa **Crear**.
5. El temporizador aparece en la sección *Timers*, contando hacia atrás.

> **Regla de validación**: la duración debe ser positiva y el título no vacío.

### CU-2: Crear una alarma
1. **Add Alarm…** (`A`).
2. Se elige una fecha/hora futura y un título. Opcionalmente se activa el snooze.
3. La alarma aparece en *Alarms* con la hora formateada (`14:30`, `Tomorrow 09:00`).

> **Regla de validación**: la fecha debe ser estrictamente futura y el título no vacío.

### CU-3: Crear un cronómetro
1. **Add Stopwatch…** (`S`).
2. Se introduce un título y se crea. Empieza a contar desde 0.
3. Mientras corre, el botón `⏸` permite pausar; `▶` reanudar.

### CU-4: Crear un pomodoro
1. **Add Pomodoro…** (`P`).
2. Se definen minutos de trabajo, minutos de descanso y nº de ciclos.
3. Aparece en *Pomodoros*, mostrando la fase actual (*Work* / *Break*) y el tiempo.

### CU-5: Editar un item
1. Se **hace clic en el título** del item en el menú (el cursor cambia a mano).
2. Se abre la ventana de edición con los campos rellenados.
3. Al guardar, los valores se recalculan desde el instante actual (p. ej. cambiar
   la duración de un temporizador en marcha reinicia su cuenta atrás desde ese momento).

### CU-6: Eliminar / limpiar un item
1. El botón de la derecha (icono 🗑 para items en marcha, ✓ para items terminados)
   elimina el item.
2. **Items en marcha**: pide confirmación (“Delete X?”) con un diálogo modal.
3. **Items terminados**: se eliminan inmediatamente, sin confirmación (acción “Clear”).

### CU-7: Recibir una notificación
Cuando un temporizador o alarma dispara:
- Suena un **sonido empaquetado** (`timer_sound.wav` para timers,
  `alarm_sound.wav` para alarmas, este último repetido 3 veces).
- Aparece un **banner** con título (“Timer finished” / “Alarm”) y el texto del item.
- El banner es **persistente** (no se auto-oculta) porque se marca como
  `timeSensitive`.
- Si el item es repetido, tras la notificación se reprograma el siguiente disparo.

## 4. Estado de un item

Cada item puede estar en uno de tres estados:

| Estado | Significado |
|---|---|
| **Running** | Contando (hacia abajo para timers/alarma, hacia arriba para cronómetro). |
| **Paused** | En pausa. Solo aplica a cronómetros. |
| **Finished** | Llegó a su `fireDate` y ya no cuenta. Muestra “Done” y el botón pasa a ✓ (Clear). |

## 5. Orden y agrupación en el menú

El menú muestra los items agrupados por tipo en secciones con cabecera coloreada:
**Timers**, **Alarms**, **Pomodoros**, **Stopwatches**. Dentro de cada grupo:

- Timers/Alarmas en marcha se ordenan por **fecha de disparo más próxima primero**.
- Pomodoros por fase (trabajo antes que descanso) y luego fecha de disparo.
- Cronómetros por fecha de creación (más antiguos primero).
- Items terminados se mandan al final.

Mientras el menú está abierto, los contadores se **actualizan cada segundo en
sitio** (sin reconstruir el menú).

## 6. Ventanas auxiliares

- **Formularios** (Add Timer / Alarm / Stopwatch / Pomodoro y Edit): ventanas
  ligeras, centradas, no redimensionables, alojadas con SwiftUI. Cada una es
  **singleton**: si ya está abierta, re-invocar simplemente la trae al frente.
- **About**: ventana “Acerca de” con icono, nombre, versión (leída del bundle) y
  autor.

## 7. Límites y comportamiento esperado

- **Requisito**: macOS 13 Ventura o superior; Xcode 16+ para compilar.
- **Notificaciones**: requieren permiso del usuario. Si se deniega, la app sigue
  funcionando pero no muestra banners (el sonido, sin embargo, se reproduce
  directamente vía `NSSound`, por lo que sí suena).
- **Suspensión del equipo**: mientras el Mac está dormido los items no disparan;
  al despertar se reconcilian contra el reloj real.
- **Sonido crítico**: la app **ignora No Molestar / Concentración** para el sonido
  (se reproduce con `NSSound`, no con el centro de notificaciones). Es
  intencional: si pones un temporizador, quieres que suene.
