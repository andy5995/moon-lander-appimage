#!/bin/bash

set -ev

if [ -z "$DOCKER_BUILD" ]; then
  echo "This script is only meant to be used with the linuxdeploy build"
  echo "helper container."
  echo "See the moon-lander-appimage README for details."
  exit 1
fi

if [ -z "$VERSION" ]; then
  echo "VERSION must be set (e.g. 1.0-10)"
  exit 1
fi

if [[ "$WORKSPACE" != /* ]]; then
  echo "The workspace path must be absolute"
  exit 1
fi

test -d "$WORKSPACE"

APPDIR=${APPDIR:-"/tmp/$USER-AppDir"}

if [ -d "$APPDIR" ]; then
  rm -rf "$APPDIR"
fi
mkdir -v -p "$APPDIR"

env
export -p

cd "$WORKSPACE"

if [ ! -e "AppRun" ]; then
  echo "You must be in the same directory where the AppRun file resides"
  exit 1
fi

# ---------------------------------------------------------------------------
# Install build-time dependencies
# ---------------------------------------------------------------------------

sudo DEBIAN_FRONTEND=noninteractive sh -c "
  apt-get update && apt-get -y upgrade && \\
  apt-get install -y \\
    build-essential \\
    git \\
    icoutils \\
    quilt \\
    libsdl1.2-dev \\
    libsdl-mixer1.2-dev \\
    libsdl-image1.2-dev \\
    patchelf \\
"

# ---------------------------------------------------------------------------
# Clone source from Salsa and build
# ---------------------------------------------------------------------------

SRC_TREE="$WORKSPACE/moon-lander"

if [ ! -d "$SRC_TREE" ]; then
  git clone --depth=1 https://salsa.debian.org/games-team/moon-lander.git "$SRC_TREE"
fi

cd "$SRC_TREE"

# Apply all Debian patches via quilt
export QUILT_PATCHES=debian/patches
if [ -f debian/patches/series ]; then
  quilt push -a || true
fi

# Rewrite the hardcoded DATAPATH to a relative path. AppRun will cd to
# $HERE (the AppImage root) before exec, so ./usr/share/moon-lander/
# resolves correctly regardless of where the AppImage is mounted.
sed -i 's|#define DATAPATH "/usr/share/games/moon-lander/"|#define DATAPATH "./usr/share/moon-lander/"|' \
  "$SRC_TREE/moon_lander.c"

# Build with plain make
make -j"$(nproc)"

BINARY="$SRC_TREE/moon-lander"
if [ ! -x "$BINARY" ]; then
  echo "ERROR: moon-lander binary not found after build"
  exit 1
fi

# ---------------------------------------------------------------------------
# Populate AppDir
# ---------------------------------------------------------------------------

# Binary
install -Ds "$BINARY" "$APPDIR/usr/games/moon-lander"

# Data files live directly in the repo root (no data/ subdirectory)
mkdir -p "$APPDIR/usr/share/moon-lander"
for d in fonts images sounds; do
  if [ -d "$SRC_TREE/$d" ]; then
    cp -a "$SRC_TREE/$d" "$APPDIR/usr/share/moon-lander/"
  else
    echo "WARNING: expected data directory '$d' not found in $SRC_TREE"
  fi
done

# Desktop file — shipped in debian/ directory
DESKTOP_SRC=$(find "$SRC_TREE/debian" -name "*.desktop" 2>/dev/null | head -1)
if [ -n "$DESKTOP_SRC" ]; then
  install -D "$DESKTOP_SRC" "$APPDIR/usr/share/applications/moon-lander.desktop"
else
  mkdir -p "$APPDIR/usr/share/applications"
  cat > "$APPDIR/usr/share/applications/moon-lander.desktop" <<EOF
[Desktop Entry]
Name=Moon Lander
Comment=Game based on the classic moon lander
Exec=moon-lander
Icon=moon-lander
Type=Application
Categories=Game;ArcadeGame;
EOF
fi

# Icon — extract from the .ico file exactly as the Debian rules file does
mkdir -p "$APPDIR/usr/share/pixmaps"
icotool -x --index=1   -o "$APPDIR/usr/share/pixmaps/moon-lander.png"   "$SRC_TREE/images/moon-lander.ico"
ICON_FILE="$APPDIR/usr/share/pixmaps/moon-lander.png"


# ---------------------------------------------------------------------------
# Run linuxdeploy to bundle shared libraries and finalise the AppDir
# ---------------------------------------------------------------------------

cd "$WORKSPACE"

OUT_DIR="$WORKSPACE/out"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

ARCH=$(uname -m)
export LINUXDEPLOY_OUTPUT_VERSION="$VERSION"

linuxdeploy \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/games/moon-lander" \
  --desktop-file "$APPDIR/usr/share/applications/moon-lander.desktop" \
  --icon-file "$ICON_FILE" \
  --icon-filename moon-lander \
  --custom-apprun "$WORKSPACE/AppRun"

# ---------------------------------------------------------------------------
# Pack the AppImage
# ---------------------------------------------------------------------------

OUT_APPIMAGE="moon-lander-$VERSION-$ARCH.AppImage"

REPO="moon-lander-appimage"
TAG="latest"
GITHUB_REPOSITORY_OWNER="${GITHUB_REPOSITORY_OWNER:-your-github-username}"
UPINFO="gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|$REPO|$TAG|*$ARCH.AppImage.zsync"

appimagetool \
  --comp zstd \
  --mksquashfs-opt -Xcompression-level \
  --mksquashfs-opt 20 \
  -u "$UPINFO" \
  "$APPDIR" "$OUT_APPIMAGE"

sha1sum "$OUT_APPIMAGE" > "$OUT_APPIMAGE.sha1sum"
cat "$OUT_APPIMAGE.sha1sum"

exit 0
