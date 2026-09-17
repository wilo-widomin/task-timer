#!/usr/bin/env bash
# Build de Release + .dmg para distribución a usuarios de confianza.
#
# Uso:
#   ./scripts/build-release.sh                 # usa la versión del proyecto
#   ./scripts/build-release.sh 1.0.1           # marca la versión a 1.0.1
#
# Produce: dist/MenuTimer-<version>.dmg
#
# Requiere:
#   - Cert "Apple Development" en el llavero.
#
# Firma AUTOMÁTICA, igual que widomin-office y EmailNotifier. Xcode elige el
# cert del llavero y gestiona el perfil con -allowProvisioningUpdates, así que
# no hay que averiguar el hash SHA-1 de ningún certificado.
# Esta app no tiene entitlements, pero se firma igual que las otras para que el
# procedimiento sea uno solo en los tres repos.
# No hay notarización: para repartir a usuarios de confianza, la primera vez
# deben abrir con clic derecho → Abrir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/MenuTimer.xcodeproj"
SCHEME="MenuTimer"
CONFIG="Release"

# Team ID para la firma automática. Sobrescribe con la variable de entorno
# DEVELOPMENT_TEAM si cambias de cuenta. Debe coincidir con el Team que
# tienes seleccionado en Xcode → Signing & Capabilities.
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-7NZNHD46LC}"

echo "==> Firmando (automática) con Team: $DEVELOPMENT_TEAM"

VERSION="${1:-}"

BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/MenuTimer.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DIST_DIR="$REPO_ROOT/dist"

echo "==> Limpiando build/ y dist/"
rm -rf "$BUILD_DIR" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR" "$EXPORT_DIR"

# ---- Versión ----
if [[ -n "$VERSION" ]]; then
    echo "==> Marcando MARKETING_VERSION=$VERSION"
    VERSION_OVERRIDE=(MARKETING_VERSION="$VERSION")
else
    VERSION_OVERRIDE=()
fi

# ---- Archive (firma automática; Xcode gestiona el perfil) ----
echo "==> Archive"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    ${VERSION_OVERRIDE[@]+"${VERSION_OVERRIDE[@]}"} \
    archive

# ---- Extraer la .app del archive (ya viene firmada) ----
echo "==> Extrayendo la app del archive"
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/MenuTimer.app"
if [[ ! -d "$ARCHIVED_APP" ]]; then
    echo "ERROR: no se encontró $ARCHIVED_APP" >&2
    exit 1
fi
cp -R "$ARCHIVED_APP" "$EXPORT_DIR/"
APP_PATH="$EXPORT_DIR/MenuTimer.app"

# ---- Verificar la firma ----
echo "==> Verificando firma"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --display --verbose=2 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier" || true

# ---- Leer versión final si no se pasó por argumento ----
if [[ -z "$VERSION" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
        "$APP_PATH/Contents/Info.plist")
fi

DMG_PATH="$DIST_DIR/MenuTimer-$VERSION.dmg"

# ---- Empaquetar DMG ----
echo "==> Empaquetando $DMG_PATH"
rm -f "$DMG_PATH"

DMG_STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
    -volname "MenuTimer $VERSION" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "==> Hecho"
echo "    App:  $APP_PATH"
echo "    DMG:  $DMG_PATH"
echo ""
echo "Pasos para repartirlo:"
echo "  1. Comparte $DMG_PATH con los usuarios."
echo "  2. Que arrastren MenuTimer.app a Applications."
echo "  3. Primera vez: clic derecho sobre la app → Abrir → Abrir."
