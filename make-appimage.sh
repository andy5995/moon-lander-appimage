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

# Relocatability: moon-lander hardcodes a compile-time DATAPATH for every
# asset load (no XDG lookup). Make it read MOON_LANDER_DATAPATH at runtime,
# falling back to the normal FHS path when run installed. The AppDir .env
# below points it at the bundled data via sharun's ${SHARUN_DIR}.
sed -i '/#define DATAPATH/c\
static const char *ml_datapath(void){const char*p=getenv("MOON_LANDER_DATAPATH");return (p&&*p)?p:"/usr/share/games/moon-lander/";}\
#define DATAPATH ml_datapath()' moon_lander.c

make -j"$(nproc)"
test -x "$SRC/moon-lander"

# ---------------------------------------------------------------------------
# Assemble the AppDir
# ---------------------------------------------------------------------------
rm -rf "$APPDIR"
mkdir -p "$APPDIR/share/moon-lander" "$APPDIR/share/applications" "$APPDIR/share/pixmaps"
for d in fonts images sounds; do cp -a "$SRC/$d" "$APPDIR/share/moon-lander/"; done

cp "$SRC/debian/moon-lander.desktop" "$APPDIR/share/applications/moon-lander.desktop"
icotool -x --index=1 -o "$APPDIR/share/pixmaps/moon-lander.png" "$SRC/images/moon-lander.ico"

printf 'MOON_LANDER_DATAPATH=${SHARUN_DIR}/share/moon-lander/\n' > "$APPDIR/.env"

# ---------------------------------------------------------------------------
# Bundle with sharun and pack the AppImage
# ---------------------------------------------------------------------------
export APPDIR
export ICON="$APPDIR/share/pixmaps/moon-lander.png"
export DESKTOP="$APPDIR/share/applications/moon-lander.desktop"
export OUTPATH
export OUTNAME="moon-lander-$VERSION-$ARCH.AppImage"
export MAIN_BIN=moon-lander
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
./quick-sharun "$SRC/moon-lander" $CODECS
./quick-sharun --make-appimage

cd "$OUTPATH"
sha256sum "$OUTNAME" > "$OUTNAME.sha256sum"
cat "$OUTNAME.sha256sum"
