---
dominio: disparo
actualizado: 2026-08-02
archivos:
  - Sources/MenuTimerKit/Engine/FireScheduler.swift
  - Sources/MenuTimerKit/Engine/TickEngine.swift
  - MenuTimer/Engine/FireScheduler.swift
  - MenuTimer/Engine/TickEngine.swift
depende_de: [items/_dominio, notificaciones/_dominio]
---

# Disparo

Cuándo salta un item y qué le pasa después. Dos piezas: un reloj de 1 Hz que empuja el
tiempo (`TickEngine`) y la máquina de estados que decide qué ha vencido
(`FireScheduler`).

## Piezas

- `TickEngine` — `Timer` de 1 s con `tolerance` 0.1, añadido a `RunLoop.main` en modo
  `.common`. Ese modo es imprescindible: en el modo por defecto el reloj se congela
  mientras hay un menú abierto y las cuentas atrás se quedarían clavadas.
- `FireScheduler.process(items:now:)` — recorre la lista, muta en el sitio lo que ha
  vencido y **devuelve los items que acaban de saltar**.
- `TimerStore.tick(now:)` — pega ambas: llama al scheduler, y solo si algo saltó
  reordena, notifica y persiste.
- `TimerStore.reconcile(now:)` — un `tick` con otro nombre. Se llama al arrancar y al
  activarse la app.

## Invariantes

- Un item «acaba de saltar» si está `.running`, ha alcanzado su `fireDate` y
  `didNotify == false`. Ese flag es lo que garantiza **una notificación por disparo**,
  aunque el tick se repita o la app se reinicie.
- Los cronómetros nunca disparan: el scheduler los salta.
- No repetitivo → `.finished` con `didNotify = true`.
- Repetitivo → `fireDate += repeatInterval`, `remainingCycles` decrece si es finito y
  `didNotify` vuelve a `false`. En el último ciclo termina como uno normal.
- Pomodoro → alterna fase: trabajo agotado pasa a descanso (`fireDate = now + breakDuration`),
  descanso agotado vuelve a trabajo y consume un ciclo.

## Trampas

- `tick` **sale antes de tocar nada si no ha saltado ningún item**. Es deliberado: no
  invalida `@Published` sesenta veces por minuto. Consecuencia importante: **la cuenta
  atrás que ve el usuario no se refresca desde aquí**. Cada interfaz pone su propio
  reloj — `MenuRefresher` en la app, y un `TimelineView(.periodic(…by: 1))` en el
  listado SwiftUI. Sin ese reloj propio, los tiempos se quedan congelados hasta que
  algo más provoque un redibujado.
- Tras dormir el equipo el tick no ha corrido: por eso hay que llamar a `reconcile`
  al activarse la app, o los items vencidos durante el sueño no saltan hasta el
  siguiente segundo.
- `process` muta `items` por `inout` **y** devuelve los disparados: los devueltos son
  una foto *previa* a la mutación, que es lo que se pasa a las notificaciones.
- El `TickEngine` guarda el handler fuerte: pásale `[weak store]` o mantendrás vivo el
  store para siempre.
