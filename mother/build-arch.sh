#!/usr/bin/env bash
# Build xdg-desktop-portal-kde 6.7.5-1.1 as an Arch package inside archlinux:latest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOTHER="$ROOT/mother"
DIST="$MOTHER/dist"
PKGVER="6.7.5"
PKGNAME="xdg-desktop-portal-kde"
TARBALL="$MOTHER/${PKGNAME}-${PKGVER}.tar.xz"
JOBS="$(nproc)"

if command -v docker >/dev/null 2>&1; then
  ENGINE=(docker)
elif command -v podman >/dev/null 2>&1; then
  ENGINE=(podman)
else
  echo "Neither docker nor podman is available on this machine." >&2
  echo "Install one of them and re-run $0" >&2
  exit 1
fi

mkdir -p "$DIST"

echo "Creating source tarball $TARBALL"
STAGE="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGE"
  rm -f "$TARBALL"
}
trap cleanup EXIT
mkdir -p "$STAGE/${PKGNAME}-${PKGVER}"
tar -C "$ROOT" \
  --exclude='.git' \
  --exclude='mother/dist' \
  --exclude="${PKGNAME}-${PKGVER}.tar.xz" \
  -cf - . | tar -C "$STAGE/${PKGNAME}-${PKGVER}" -xf -
tar -C "$STAGE" -cJf "$TARBALL" "${PKGNAME}-${PKGVER}"

echo "Using ${ENGINE[*]} to build in archlinux:latest (MAKEFLAGS=-j${JOBS})"
"${ENGINE[@]}" pull archlinux:latest
"${ENGINE[@]}" run --rm \
  -e MAKEFLAGS="-j${JOBS}" \
  -e JOBS="$JOBS" \
  -v "$MOTHER:/pkg:rw" \
  archlinux:latest \
  /bin/bash -s <<'EOF'
set -euo pipefail
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel sudo
useradd -m -G wheel builder
echo 'builder ALL=(ALL:ALL) NOPASSWD: ALL' >/etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder
install -d -o builder -g builder /work
cp /pkg/PKGBUILD /work/
cp /pkg/xdg-desktop-portal-kde-6.7.5.tar.xz /work/
cd /work
# makepkg refuses to run as root
su -s /bin/bash builder -c 'cd /work && makepkg -s --noconfirm'
install -d /pkg/dist
cp -a /work/xdg-desktop-portal-kde-6.7.5-1.1-x86_64.pkg.tar.zst /pkg/dist/
sha256sum /work/xdg-desktop-portal-kde-6.7.5-1.1-x86_64.pkg.tar.zst | tee /pkg/dist/SHA256SUMS

echo '=== pacman -U ==='
pacman -U --noconfirm /work/xdg-desktop-portal-kde-6.7.5-1.1-x86_64.pkg.tar.zst

echo '=== ldd not found ==='
if ldd /usr/lib/xdg-desktop-portal-kde | grep 'not found'; then
  echo 'ldd reported missing libraries' >&2
  exit 1
else
  echo '(no missing libraries)'
fi

echo '=== pacman -Qip ==='
pacman -Qip /work/xdg-desktop-portal-kde-6.7.5-1.1-x86_64.pkg.tar.zst

echo '=== ctest (headless; package itself is BUILD_TESTING=OFF) ==='
# Reconfigure the existing makepkg build tree so only test targets are added.
su -s /bin/bash builder -c '
set -euo pipefail
cd /work/src
cmake -B build -S xdg-desktop-portal-kde-6.7.5 \
  -DCMAKE_INSTALL_LIBEXECDIR=lib \
  -DBUILD_TESTING=ON
cmake --build build -j"${JOBS}"
cd build
# colorschemetest launches the portal on a session bus and needs a display/desktop.
echo "Skipping colorschemetest (needs a session bus / desktop)."
ctest --output-on-failure -E colorschemetest
'
EOF

# Dist artifacts stay in mother/dist; cleanup removes the staging tarball.

echo "Package and checksums are in $DIST"
ls -l "$DIST"
