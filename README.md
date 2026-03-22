# bitwarden-deb-arm64

Builds an ARM64 Debian package (`.deb`) of the Bitwarden Desktop application from Bitwarden's official pre-built ARM64 Linux release. The package is assembled on an **amd64** host via cross-packaging (no compilation — Bitwarden ships pre-built Electron binaries).

## Repository structure

```
bitwarden-deb-arm64/
├── build.sh            # Main build script
├── debian/
│   ├── control         # Package metadata template (@@PLACEHOLDERS@@ filled by build.sh)
│   ├── changelog       # Package changelog
│   ├── copyright       # License information
│   ├── postinst        # Post-installation maintainer script
│   └── prerm           # Pre-removal maintainer script
└── README.md
```

## Prerequisites

Install the following packages on your **amd64** build machine:

```bash
sudo apt-get update
sudo apt-get install -y curl fakeroot dpkg
```

| Tool        | Purpose                                      |
|-------------|----------------------------------------------|
| `curl`      | Download Bitwarden release archive           |
| `fakeroot`  | Build the `.deb` with correct root ownership |
| `dpkg-deb`  | Assemble the Debian package (part of `dpkg`) |

> No cross-compilation toolchain is needed — Bitwarden provides pre-built ARM64 binaries.

## Building the package

```bash
git clone https://github.com/<your-user>/bitwarden-deb-arm64.git
cd bitwarden-deb-arm64
chmod +x build.sh
./build.sh
```

The script will:
1. Download `bitwarden_<VERSION>_arm64.tar.gz` from the official GitHub release.
2. Extract the Electron application bundle.
3. Assemble the Debian package directory structure under `build/`.
4. Generate `DEBIAN/control` from the `debian/control` template.
5. Copy maintainer scripts (`postinst`, `prerm`).
6. Create a `/usr/bin/bitwarden` launcher wrapper and a `.desktop` entry.
7. Build `bitwarden_<VERSION>_arm64.deb` using `fakeroot dpkg-deb`.
8. Clean up the temporary `build/` directory.

The final package will be written to the repository root:

```
bitwarden_2026.2.1_arm64.deb
```

## Updating the Bitwarden version

Edit the version variable at the top of `build.sh`:

```bash
BITWARDEN_VERSION="2026.2.1"   # ← change this
```

Also update `debian/changelog` to reflect the new version:

```
bitwarden (2026.3.0) stable; urgency=low

  * Packaged Bitwarden Desktop 2026.3.0 for ARM64

 -- Your Name <you@example.com>  Mon, 01 Jun 2026 00:00:00 +0000
```

## Customising the maintainer name

Set the `MAINTAINER` variable in `build.sh`:

```bash
MAINTAINER="Your Name <you@example.com>"
```

## Verifying the package

Inspect package metadata before installing:

```bash
dpkg-deb -I bitwarden_2026.2.1_arm64.deb   # show control fields
dpkg-deb -c bitwarden_2026.2.1_arm64.deb   # list package contents
```

## Installing on an ARM64 device

Transfer the `.deb` to your ARM64 machine and install:

```bash
sudo dpkg -i bitwarden_2026.2.1_arm64.deb
sudo apt-get install -f        # install any missing dependencies
```

To remove the package:

```bash
sudo dpkg -r bitwarden
```

## Installed file layout

| Path                                          | Description                       |
|-----------------------------------------------|-----------------------------------|
| `/opt/Bitwarden/`                             | Electron application bundle       |
| `/usr/bin/bitwarden`                          | Launcher wrapper script           |
| `/usr/share/applications/bitwarden.desktop`   | Desktop entry                     |
| `/usr/share/icons/hicolor/*/apps/bitwarden.png` | Application icons (if bundled)  |

## Runtime dependencies

The package declares the following Debian dependencies, which are installed automatically by `apt`:

```
libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6,
xdg-utils, libatspi2.0-0, libdrm2, libgbm1, libsecret-1-0
```

## License

The Bitwarden client is licensed under the [GNU General Public License v3.0](https://github.com/bitwarden/clients/blob/main/LICENSE.txt).  
This packaging repository is provided as-is with no warranty.

