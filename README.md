# moon-lander-appimage

Unofficial [moon-lander](https://salsa.debian.org/games-team/moon-lander)
[AppImage](https://appimage.org/), built from the Debian Salsa packaging repo.

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

You need Docker (or a compatible runtime) installed.

```bash
# From the repo root:
export HOSTUID=$(id -u) HOSTGID=$(id -g)
docker compose -f ./docker-compose.yml run --rm build
```

The finished AppImage (and its `.sha1sum` and `.zsync` sidecar files) will
appear in `./out/`.

### Override the AppImage version label

`VERSION` is used only as a label in the output filename — it does not pin a
package version. The source is always cloned from the Salsa repo's default branch.

```bash
VERSION=1.0-10 docker compose -f ./docker-compose.yml run --rm build
```

### Drop into a shell for debugging

```bash
export HOSTUID=$(id -u) HOSTGID=$(id -g)
docker compose -f ./docker-compose.yml run --rm build bash
```

### Override the build script

```bash
SCRIPT=/workspace/my-custom-script.sh \
  docker compose -f ./docker-compose.yml run --rm build
```

## GitHub Actions

Two triggers are configured:

| Trigger | What happens |
|---|---|
| Push to `trunk` / `main` | Builds the AppImage and publishes/updates the `latest` release |
| `workflow_dispatch` | Builds the AppImage and uploads it as a workflow artifact (no release) |

## About

Built with [andy5995/linuxdeploy](https://hub.docker.com/r/andy5995/linuxdeploy)
(`v3-jammy`), which bundles
[linuxdeploy](https://github.com/linuxdeploy/linuxdeploy) and
[appimagetool](https://github.com/AppImage/appimagetool).

Source: [salsa.debian.org/games-team/moon-lander](https://salsa.debian.org/games-team/moon-lander) —
the official Debian packaging repo, which includes the upstream source and all Debian patches.
Patches are applied via `quilt` before building with plain `make`.

## License

The build scripts, AppRun, and other files **created by this repository** are
released under the [MIT License](LICENSE).

The moon-lander game itself is under a different license. The source code is
believed to be GPL-2+, and the data files (sounds, images) may be under
additional or different free licenses. See
[`debian/copyright`](https://salsa.debian.org/games-team/moon-lander/-/blob/master/debian/copyright)
in the upstream Salsa repository for the authoritative per-file license
information.

This repository does not distribute the moon-lander source or binaries
directly — the AppImage is built from upstream sources at build time.
