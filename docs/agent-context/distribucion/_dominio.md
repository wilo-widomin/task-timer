---
dominio: distribucion
actualizado: 2026-08-02
archivos:
  - MenuTimer.xcodeproj/project.pbxproj
  - Package.swift
  - .githooks/prepare-commit-msg
  - .githooks/pre-commit
---

# Distribución

Este repo se publica de dos maneras a la vez: como app y como paquete SPM. Lo segundo
es lo que consume `widomin-app`, y va por **tags de git**.

## Versionado

- Fuente de verdad: `MARKETING_VERSION` en `MenuTimer.xcodeproj/project.pbxproj`,
  repetido en 4 sitios (Debug + Release × target de app y de tests). Todos deben ir
  iguales.
- `.githooks/prepare-commit-msg` lo sube según el prefijo del commit: `feat!:` mayor,
  `feat:` menor, `fix:` parche. Instalar con `git config core.hooksPath .githooks`.
- `.githooks/pre-commit` no bumpea nada; solo comprueba que el commit toca código de
  producción.

## Publicar una versión para Widomin

1. Cambiar el código en **las dos copias** (`MenuTimer/` y `Sources/MenuTimerKit/`).
2. `swift build` y compilar el target de la app.
3. Subir `MARKETING_VERSION`.
4. Commit, `git tag <versión>`, `git push origin main` y `git push origin <versión>`.
5. En `widomin-app`, subir `minimumVersion` del `XCRemoteSwiftPackageReference` en su
   `project.pbxproj`.

Sin el tag, `widomin-app` no ve nada: SPM resuelve por tags, no por `main`.

## Trampas

- El bump del hook **no entra en el commit que lo dispara** — `prepare-commit-msg` corre
  con el índice ya congelado. Hay que rematarlo con
  `git -c core.hooksPath=/dev/null commit --amend --no-edit`; sin desactivar los hooks,
  el amend vuelve a subir la versión.
- GitHub rechaza el push con `email privacy restrictions` si el commit lleva un correo
  privado. La cuenta usa `516403+widomin@users.noreply.github.com`.
- El pin de `widomin-app` es `upToNextMajor`: publicar una versión mayor deja de
  llegarle sola.
- `Package.swift` no declara `resources`, así que los `.wav` no viajan con el paquete.
  Ver `notificaciones/_dominio.md`.
