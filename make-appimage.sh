#!/bin/sh
# Build a truly-portable "Anylinux" AppImage for moon-lander using sharun +
# uruntime (https://github.com/pkgforge-dev/Anylinux-AppImages). Unlike the
# old linuxdeploy build, the result bundles its own libc and dynamic linker,
# so it runs on any distro — musl, very old glibc — with no host libraries.
#
# Run inside an Arch environment with the build deps installed (see
# .github/workflows/build.yml for the package list).
set -eux

ARCH="$(uname -m)"
HERE="$(CDPATH= cd "$(dirname "$0")" && pwd)"
VERSION="${VERSION:-$(grep '^VERSION=' "$HERE/.env" | cut -d= -f2)}"

BUILD="${BUILD:-/tmp/moon-lander-build}"
SRC="$BUILD/src"
APPDIR="$BUILD/AppDir"
OUTPATH="$HERE/out"

# The bundler. Pin to a tag/commit instead of refs/heads/main for full
# build reproducibility.
QUICK_SHARUN_URL="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"

rm -rf "$BUILD"
mkdir -p "$SRC" "$OUTPATH"

wget --retry-connrefused --tries=30 "$QUICK_SHARUN_URL" -O "$BUILD/quick-sharun"
chmod +x "$BUILD/quick-sharun"

# ---------------------------------------------------------------------------
# Pristine source from Salsa + Debian patches
# ---------------------------------------------------------------------------
git clone --depth=1 https://salsa.debian.org/games-team/moon-lander.git "$SRC"
cd "$SRC"

export QUILT_PATCHES=debian/patches
[ -f debian/patches/series ] && quilt push -a || true

make -j"$(nproc)"
test -x "$SRC/moon-lander"

# ---------------------------------------------------------------------------
# Install the binary and assets into a real /usr, then let quick-sharun deploy
# and relocate them. moon-lander hardcodes its DATAPATH at compile time (the
# Debian patches set it to /usr/share/games/moon-lander/). Rather than patching
# the source to add an env seam, we install to /usr and let quick-sharun do what
# it does for any /usr-prefixed app: rewrite the hardcoded /usr/share path in
# the binary and symlink the bundled data there at runtime. The compiled-in
# lookup then just works -- no source change, no .env.
#
# Install only the binary and assets -- not the crude upstream install.sh,
# which copies the whole source tree (.git, .o, debian/) into the datadir.
# ---------------------------------------------------------------------------
install -Dm755 "$SRC/moon-lander" /usr/bin/moon-lander
mkdir -p /usr/share/games/moon-lander
cp -a "$SRC/fonts" "$SRC/images" "$SRC/sounds" /usr/share/games/moon-lander/

icotool -x --index=1 -o "$BUILD/moon-lander.png" "$SRC/images/moon-lander.ico"

rm -rf "$APPDIR"

# ---------------------------------------------------------------------------
# Bundle with sharun and pack the AppImage
# ---------------------------------------------------------------------------
export APPDIR
export ICON="$BUILD/moon-lander.png"
export DESKTOP="$SRC/debian/moon-lander.desktop"
export OUTPATH
export OUTNAME="moon-lander-$VERSION-$ARCH.AppImage"
export UPINFO="${UPINFO:-gh-releases-zsync|${GITHUB_REPOSITORY_OWNER:-andy5995}|moon-lander-appimage|latest|*$ARCH.AppImage.zsync}"

# SDL_image 1.2 dlopens its codec libs (they are absent from ldd/NEEDED), so
# deploy them explicitly — libpng for the .png assets, libjpeg for the one
# .jpg background. GIF and BMP are built into SDL_image. Without this the
# bundle silently falls back to the host's copies and is not truly portable.
CODECS=""
for s in libpng16.so.16 libjpeg.so.8; do
  for d in /usr/lib /usr/lib64 /lib; do
    [ -e "$d/$s" ] && { CODECS="$CODECS $d/$s"; break; }
  done
done

cd "$BUILD"
# shellcheck disable=SC2086
./quick-sharun /usr/bin/moon-lander $CODECS
./quick-sharun --make-appimage

cd "$OUTPATH"
sha256sum "$OUTNAME" > "$OUTNAME.sha256sum"
cat "$OUTNAME.sha256sum"
