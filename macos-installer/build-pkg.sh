#!/bin/bash
#
# Builds a macOS .pkg installer for PhotoGIMP.
# Run from the repository root: ./macos-installer/build-pkg.sh
#
# Requirements: Xcode Command Line Tools (pkgbuild, productbuild)
# Optional:     --sign "Developer ID Installer: ..." for code signing
#
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

VERSION="3.0.0"
IDENTIFIER="com.diolinux.photogimp.config"
PKG_NAME="PhotoGIMP-${VERSION}-macOS"
SIGN_IDENTITY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            PKG_NAME="PhotoGIMP-${VERSION}-macOS"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--sign \"Developer ID Installer: Name\"] [--version X.Y.Z]"
            exit 1
            ;;
    esac
done

BUILD_DIR="$REPO_ROOT/macos-installer/build"
PAYLOAD_DIR="$BUILD_DIR/payload"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
RESOURCES_DIR="$BUILD_DIR/resources"
COMPONENT_PKG="$BUILD_DIR/PhotoGIMP-config.pkg"
OUTPUT_PKG="$BUILD_DIR/${PKG_NAME}.pkg"

rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR/3.0" "$RESOURCES_DIR"

echo "==> Assembling payload..."
rsync -a --exclude='.DS_Store' \
    "$REPO_ROOT/.config/GIMP/3.0/" \
    "$PAYLOAD_DIR/3.0/"

echo "==> Preparing scripts..."
chmod +x "$SCRIPTS_DIR/preinstall" "$SCRIPTS_DIR/postinstall"

echo "==> Preparing resources..."
cp "$SCRIPT_DIR/resources/welcome.html" "$RESOURCES_DIR/"
cp "$SCRIPT_DIR/resources/conclusion.html" "$RESOURCES_DIR/"
cp "$REPO_ROOT/LICENSE" "$RESOURCES_DIR/"

echo "==> Building component package..."
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "Library/Application Support/GIMP" \
    --scripts "$SCRIPTS_DIR" \
    "$COMPONENT_PKG"

echo "==> Building product package..."
PRODUCTBUILD_ARGS=(
    --distribution "$SCRIPT_DIR/Distribution.xml"
    --resources "$RESOURCES_DIR"
    --package-path "$BUILD_DIR"
    --version "$VERSION"
)

if [ -n "$SIGN_IDENTITY" ]; then
    PRODUCTBUILD_ARGS+=(--sign "$SIGN_IDENTITY")
    echo "    Signing with: $SIGN_IDENTITY"
fi

productbuild "${PRODUCTBUILD_ARGS[@]}" "$OUTPUT_PKG"

rm -f "$COMPONENT_PKG"

echo ""
echo "==> Build complete!"
echo "    Output: $OUTPUT_PKG"
echo "    Size:   $(du -h "$OUTPUT_PKG" | cut -f1)"
echo ""

if [ -z "$SIGN_IDENTITY" ]; then
    echo "    NOTE: This package is unsigned. Users will need to right-click > Open"
    echo "    to install it, or allow it in System Settings > Privacy & Security."
    echo ""
    echo "    To build a signed package:"
    echo "    $0 --sign \"Developer ID Installer: Your Name (TEAMID)\""
fi
