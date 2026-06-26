# moon-lander-appimage

Unofficial moon-lander [AppImage](https://appimage.org/), built from the
[Debian Salsa packaging
repo](https://salsa.debian.org/games-team/moon-lander).

Click the [Releases](../../releases) link to download the latest AppImage.

## Running

```bash
chmod +x moon-lander-*.AppImage
./moon-lander-*.AppImage
```

## Updating

The AppImage supports delta updates via
[appimageupdatetool](https://github.com/AppImageCommunity/AppImageUpdate):

```bash
appimageupdatetool moon-lander-*.AppImage
```

If the tool isn't available in your distro, you can grab it as an AppImage from
the repo above, or install it via [AM](https://github.com/ivan-hc/AM).

## Build locally

The build runs on Arch Linux. The easiest way is a throwaway Arch container:

```bash
docker run --rm -v "$PWD":/repo -w /repo archlinux:latest sh -c '
  pacman -Syu --noconfirm --needed \
    base-devel git icoutils quilt patchelf wget zsync \
    sdl12-compat sdl_image sdl_mixer fuse2 strace xorg-server-xvfb &&
  ./make-appimage.sh'
```

If you are already on Arch (or a derivative such as Manjaro), install those
packages and run `./make-appimage.sh` directly.

The finished AppImage (and its `.sha256sum` and `.zsync` sidecar files) will
appear in `./out/`.

### Override the AppImage version label

`VERSION` is used only as a label in the output filename — it does not pin a
package version. The source is always cloned from the Salsa repo's default branch.
The default is `1.0-10`, so overriding it is only needed if you want a
different label.

```bash
VERSION=1.0-11 ./make-appimage.sh
```

## GitHub Actions

Two triggers are configured:

| Trigger | What happens |
|---|---|
| Push to `trunk` / `main` | Builds the AppImage and publishes/updates the `latest` release |
| `workflow_dispatch` | Builds the AppImage and uploads it as a workflow artifact (no release) |

## About

This is an [Anylinux AppImage](https://github.com/pkgforge-dev/Anylinux-AppImages).
It is built with [sharun](https://github.com/VHSgunzo/sharun) and the
[uruntime](https://github.com/VHSgunzo/uruntime). The AppImage bundles its own
C library and dynamic linker, so it runs on any Linux distribution — including
musl-based systems and very old ones — without depending on host libraries. It
also needs no FUSE: if FUSE is missing it falls back to mount namespaces, and
if those are missing it extracts and runs from a temporary directory.

Source: [salsa.debian.org/games-team/moon-lander](https://salsa.debian.org/games-team/moon-lander) —
the official Debian packaging repo, which includes the upstream source and all Debian patches.
Patches are applied via `quilt` before building with plain `make`.

One small source change is applied at build time: the game's data path is made
relocatable so it reads the `MOON_LANDER_DATAPATH` environment variable (with
the normal `/usr/share/games/moon-lander/` path as the fallback). The AppImage
sets this variable to its own bundled data directory.

## License

The build scripts and other files **created by this repository** are
released under the [MIT License](LICENSE).

The moon-lander game itself is under a different license. The source code is
believed to be GPL-2+, and the data files (sounds, images) may be under
additional or different free licenses. See
[`debian/copyright`](https://salsa.debian.org/games-team/moon-lander/-/blob/master/debian/copyright)
in the upstream Salsa repository for the authoritative per-file license
information.

This repository does not distribute the moon-lander source or binaries
directly — the AppImage is built from upstream sources at build time.
