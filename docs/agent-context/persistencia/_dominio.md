---
dominio: persistencia
actualizado: 2026-08-02
archivos:
  - Sources/MenuTimerKit/Persistence/FileLocations.swift
  - Sources/MenuTimerKit/Persistence/JSONPersistenceService.swift
  - Sources/MenuTimerKit/Models/PersistedStore.swift
  - MenuTimer/Persistence/FileLocations.swift
depende_de: [items/_dominio]
---

# Persistencia

Un único JSON con todos los items. Se guarda solo, en cada mutación del store.

## Piezas

- `FileLocations` — resuelve `<Application Support>/<folderName>/store.json`, con
  `folderName` por defecto `"MenuTimer"`. Admite inyectar un directorio base para
  tests.
- `JSONPersistenceService` — **`actor`**: serializa todo el acceso a disco fuera del
  hilo principal. Escribe con `Data.write(options: .atomic)`.
- `PersistedStore` — el `Codable` que envuelve `[TimerItem]`.
- `PersistenceService` — protocolo (`load`/`save`) para poder inyectar dobles.

## Invariantes

- Escritura atómica siempre: un corte a media escritura no puede dejar el JSON a
  medias.
- `TimerStore.persist()` es privado y lo llama cada mutador. Nadie guarda a mano.
- Los fallos de guardado se registran con `NSLog` y **se tragan**: un error transitorio
  de disco no debe tirar la interfaz.

## Trampas

- `loadSynchronously()` existe aparte del `load()` asíncrono, y es `nonisolated`. Se
  usa en el arranque para no mostrar una lista vacía durante un instante. Es la vía que
  usa el adaptador de Widomin.
- La ruta depende del **sandbox de la app anfitriona**, no del paquete: dentro de un
  contenedor, `applicationSupportDirectory` se redirige y los datos dejan de
  compartirse con la app standalone. Por eso `widomin-app` no está sandboxed.
- `folderName` sigue siendo `"MenuTimer"` también dentro de Widomin: es intencionado,
  las dos apps comparten fichero a propósito.
- Guardar es `async` y se lanza en un `Task` desde `persist()`: al salir de la app, un
  guardado recién disparado puede no llegar a completarse.
