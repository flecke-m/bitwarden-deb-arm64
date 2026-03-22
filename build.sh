#!/bin/bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
BITWARDEN_VERSION="2026.2.1"
ARCH="arm64"
PKG_NAME="bitwarden"
INSTALL_PREFIX="/opt/Bitwarden"
MAINTAINER="Matthias Fleckenstein <internet@fleckenstein-cloud.de>"

# ─── Derived variables ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAR_URL="https://github.com/bitwarden/clients/releases/download/desktop-v${BITWARDEN_VERSION}/bitwarden_${BITWARDEN_VERSION}_${ARCH}.tar.gz"
BUILD_DIR="${SCRIPT_DIR}/build"
PKG_DIR="${BUILD_DIR}/${PKG_NAME}_${BITWARDEN_VERSION}_${ARCH}"
DEB_OUT="${SCRIPT_DIR}/${PKG_NAME}_${BITWARDEN_VERSION}_${ARCH}.deb"

# ─── Cleanup ──────────────────────────────────────────────────────────────────
echo "==> Cleaning up previous build..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/extract"

# ─── Download ─────────────────────────────────────────────────────────────────
echo "==> Downloading Bitwarden ${BITWARDEN_VERSION} (${ARCH})..."
curl -fL --progress-bar "${TAR_URL}" -o "${BUILD_DIR}/bitwarden.tar.gz"

# ─── Extract ──────────────────────────────────────────────────────────────────
echo "==> Extracting archive..."
tar -xzf "${BUILD_DIR}/bitwarden.tar.gz" -C "${BUILD_DIR}/extract"

# Locate extracted content:
# - If the archive is a single-directory tarball (no files at depth 1), descend into it.
# - Otherwise (flat archive — files sit at root level), use the extract dir directly.
FILE_COUNT=$(find "${BUILD_DIR}/extract" -maxdepth 1 -mindepth 1 -type f | wc -l)
DIR_COUNT=$(find "${BUILD_DIR}/extract" -maxdepth 1 -mindepth 1 -type d | wc -l)
if [ "${FILE_COUNT}" -eq 0 ] && [ "${DIR_COUNT}" -eq 1 ]; then
    EXTRACT_SRC=$(find "${BUILD_DIR}/extract" -maxdepth 1 -mindepth 1 -type d | head -1)
else
    EXTRACT_SRC="${BUILD_DIR}/extract"
fi

# ─── Package directory structure ──────────────────────────────────────────────
echo "==> Creating package directory structure..."
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}${INSTALL_PREFIX}"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/512x512/apps"

# ─── Copy application files ───────────────────────────────────────────────────
echo "==> Copying application files..."
cp -r "${EXTRACT_SRC}/." "${PKG_DIR}${INSTALL_PREFIX}/"

# ─── Launcher wrapper ─────────────────────────────────────────────────────────
cat > "${PKG_DIR}/usr/bin/${PKG_NAME}" << 'WRAPPER'
#!/bin/bash
exec /opt/Bitwarden/bitwarden "$@"
WRAPPER
chmod 755 "${PKG_DIR}/usr/bin/${PKG_NAME}"

# ─── Icons ────────────────────────────────────────────────────────────────────
for icon_size in 16 32 64 128 256 512 1024; do
    mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/${icon_size}x${icon_size}/apps"
    for icon_path in \
        "${PKG_DIR}${INSTALL_PREFIX}/resources/icons/${icon_size}x${icon_size}.png" \
        "${PKG_DIR}${INSTALL_PREFIX}/icons/${icon_size}x${icon_size}.png" \
        "${PKG_DIR}${INSTALL_PREFIX}/resources/app.asar.unpacked/apps/desktop/build/icons/${icon_size}x${icon_size}.png" \
        "${PKG_DIR}${INSTALL_PREFIX}/${icon_size}x${icon_size}.png" \
        "${PKG_DIR}${INSTALL_PREFIX}/bitwarden.png"; do
        if [ -f "${icon_path}" ]; then
            cp "${icon_path}" "${PKG_DIR}/usr/share/icons/hicolor/${icon_size}x${icon_size}/apps/bitwarden.png"
            echo "==> ${icon_size}x${icon_size} icon copied from ${icon_path}"
            break
        fi
    done
done

# ─── Desktop entry ────────────────────────────────────────────────────────────
cat > "${PKG_DIR}/usr/share/applications/${PKG_NAME}.desktop" << DESKTOP
[Desktop Entry]
Name=Bitwarden
Comment=A secure and free password manager
GenericName=Password Manager
Exec=/opt/Bitwarden/bitwarden %U
Terminal=false
Type=Application
Icon=bitwarden
StartupWMClass=Bitwarden
Categories=Utility;Security;
MimeType=x-scheme-handler/bitwarden;
DESKTOP

# ─── File permissions ─────────────────────────────────────────────────────────
echo "==> Setting file permissions..."
find "${PKG_DIR}" -not -path "${PKG_DIR}/DEBIAN/*" -type f -exec chmod 644 {} \;
find "${PKG_DIR}" -not -path "${PKG_DIR}/DEBIAN/*" -type d -exec chmod 755 {} \;
chmod 755 "${PKG_DIR}/usr/bin/${PKG_NAME}"

# Make ELF binaries and shared libraries executable
find "${PKG_DIR}${INSTALL_PREFIX}" -type f \( -name "*.so" -o -name "*.so.*" \) -exec chmod 755 {} \;
# Make ELF binaries at the root of the install prefix executable (files without extension)
find "${PKG_DIR}${INSTALL_PREFIX}" -maxdepth 1 -type f ! -name '*.*' -exec chmod 755 {} \;

# ─── DEBIAN/control ───────────────────────────────────────────────────────────
INSTALLED_SIZE=$(du -sk "${PKG_DIR}" | awk '{print $1}')
sed \
    -e "s|@@VERSION@@|${BITWARDEN_VERSION}|g" \
    -e "s|@@ARCH@@|${ARCH}|g" \
    -e "s|@@MAINTAINER@@|${MAINTAINER}|g" \
    -e "s|@@INSTALLED_SIZE@@|${INSTALLED_SIZE}|g" \
    "${SCRIPT_DIR}/debian/control" > "${PKG_DIR}/DEBIAN/control"

# ─── DEBIAN maintainer scripts ────────────────────────────────────────────────
cp "${SCRIPT_DIR}/debian/postinst" "${PKG_DIR}/DEBIAN/postinst"
chmod 755 "${PKG_DIR}/DEBIAN/postinst"

cp "${SCRIPT_DIR}/debian/prerm" "${PKG_DIR}/DEBIAN/prerm"
chmod 755 "${PKG_DIR}/DEBIAN/prerm"

# ─── Build .deb ───────────────────────────────────────────────────────────────
echo "==> Building Debian package with fakeroot..."
fakeroot dpkg-deb --build "${PKG_DIR}" "${DEB_OUT}"

echo ""
echo "=============================="
echo " Package built successfully! "
echo "=============================="
echo " Output: ${DEB_OUT}"
echo ""
echo " To verify the package:"
echo "   dpkg-deb -I $(basename "${DEB_OUT}")"
echo ""
echo " To install on an ARM64 device:"
echo "   sudo dpkg -i $(basename "${DEB_OUT}")"
echo "   sudo apt-get install -f   # to resolve any missing dependencies"
echo ""

echo "==> Cleaning up build directory..."
rm -rf "${BUILD_DIR}"


