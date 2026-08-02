# Contexto del proyecto — Menu Timer

Temporizadores, alarmas, cronómetros y pomodoros para macOS. El repo produce **dos
cosas**: la app de barra de menús `MenuTimer` y el paquete SPM `MenuTimerKit`, que
consume Widomin como uno de sus módulos.

Lee primero el dominio que corresponda a la tarea. No explores el código sin haber
mirado su documento.

| Si la tarea trata de… | Abre |
|---|---|
| temporizador, alarma, cronómetro, pomodoro, crear, editar, borrar, pausar, orden de la lista, repeticiones, ciclos | `items/` |
| cuándo salta, tick, cuenta atrás, vencimiento, dormir el equipo, fases del pomodoro | `disparo/` |
| aviso, sonido, notificación, permisos, No Molestar | `notificaciones/` |
| guardar, store.json, Application Support, dónde están los datos | `persistencia/` |
| menú, popover, listado, filas, secciones, botones, aspecto | `interfaz/` |
| ventanas de crear o editar, validación de campos | `formularios/` |
| versión, tag, publicar para Widomin, hook de commit | `distribucion/` |

Transversal:
- `arquitectura.md` — stack, los dos productos, y **la duplicación de fuentes**.

## Antes de tocar código

`MenuTimer/` y `Sources/MenuTimerKit/` son **copias del mismo código**, y solo la
segunda lleva `public`. Un cambio de lógica va en las dos o la app y el paquete
divergen sin avisar. Detalle en `arquitectura.md`.

## Mapa rápido

- `Sources/MenuTimerKit/` — el paquete que consume Widomin
- `MenuTimer/` — la app standalone (incluye `MenuUI/`, que es solo suya)
- `MenuTimerTests/` — prueban el target de la app, **no** el paquete
- `docs/01-funcional.md`, `02-*`, `03-*` — de julio, anteriores a `MenuTimerKit`
