# Secure boot on QEMU — Zephyr + TF-M

Hands-on exercises on secure boot with TF-M's bootloader (BL2, based on MCUboot) and
Zephyr, running on an emulated Arm Cortex-M33 board (`mps2/an521`) in QEMU. No hardware
needed.

You will see the bootloader:

- boot a correctly signed image,
- reject an image that was modified after signing,
- reject an image signed with a key the device does not trust,
- ignore a staged upgrade that is not marked as ready,
- apply a staged upgrade that is.

Everything (compiler, Zephyr SDK, Zephyr 3.7.2 and its modules, Python tools, QEMU) is
inside a Docker image. On your machine you only need Git and Docker, and any other Zephyr
installation you have is not touched.

## Requirements

- Linux on an x86_64 PC (a Linux VM works too).
- Git.
- Docker, usable without `sudo`. Check with `docker run --rm hello-world`.
- About 5 GB of free disk space and an internet connection for the first setup.

## 1. Get the project

Clone it into any folder outside your course workspace:

```
git clone -b l7-secure-boot-demo https://github.com/iomico-public/zephyr-intermediate.git ~/secure-boot-app
```

```
cd ~/secure-boot-app
```

**All commands from here on are run from `~/secure-boot-app`.**

## 2. Build the Docker image

The image definition is in the `docker/` folder of this repository. Build it with:

```
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t zephyr-sb:3.7.2 docker
```

- `-t zephyr-sb:3.7.2` is the image name. The scripts look for exactly this name, so do
  not change it.
- `UID` / `GID` make the container user match your user, so the files it creates
  belong to you and not to root.

This downloads the Zephyr SDK, Zephyr 3.7.2 and its modules (TF-M, MCUboot, mbedTLS, ...)
into the image. It takes 10–20 minutes and is only needed once. The memory isolation
homework uses the same image, so if you already built it there, skip this step. Check it
worked:

```
docker image ls zephyr-sb
```

## 3. Run the container

`scripts/dev.sh` starts the container for you. It mounts this project folder inside the
container at `/opt/zephyr-ws/secure-boot-app`, so files you edit on your machine are the
same files the container sees. Zephyr is next to it, at `/opt/zephyr-ws/zephyr`. Only this
folder is kept: changes anywhere else inside the container are lost when it exits.

Open an interactive shell inside the container:

```
./scripts/dev.sh
```

Type `exit` to leave it. You can also run a single command inside the container
without opening a shell:

```
./scripts/dev.sh west --version
```

## 4. Run the exercises

`scripts/demo.sh` runs one exercise from start to end: it builds the firmware, modifies
the image if the exercise needs it, and boots it in QEMU. Every command it runs is
printed with a `+` in front, so you can see and repeat each step yourself.

Run it on your machine (not inside the container shell). It starts the container by
itself:

```
./scripts/demo.sh <exercise>
```

Good to know before you start:

- **The first build of each exercise can take a few minutes.** Later runs reuse the
  build and start much faster. To force a rebuild, put `FORCE=1` in front:
  `FORCE=1 ./scripts/demo.sh success`.
- **QEMU stops by itself after 25 seconds.** The emulated board has no power-off, so a
  timer ends the run. This is normal, not an error. Change it with `TIMEOUT`, for
  example `TIMEOUT=10 ./scripts/demo.sh tamper`.
- Every build prints `CMake Warning: TFM_DUMMY_PROVISIONING is enabled ... NOT secure!`.
  This is expected. The device uses publicly known test keys, which is what makes the
  `wrong-key` exercise possible.
- Build output goes to `build-*` folders in this project, and modified images go to
  `out/`.

### Exercise 1 — `success`: a signed image boots

```
./scripts/demo.sh success
```

Builds Zephyr's `psa_protected_storage` sample together with TF-M, signed with the
default keys, and boots it.

What to look for: the bootloader starts (`Starting bootloader`), checks the
signature (`sig_type: EC-P256`), and hands over to TF-M and then Zephyr — you see the
TF-M banner and then the Zephyr banner (`*** Booting Zephyr OS ...`).

### Exercise 2 — `tamper`: a modified image is rejected

```
./scripts/demo.sh tamper
```

Takes the image from exercise 1, changes **one byte** inside the application (at
address `0x00102000`) using `scripts/hexlab.py`, and boots the result.

What to look for: `Image in the primary slot is not valid!` and
`Unable to find bootable image`. Neither the TF-M nor the Zephyr banner appears — the
device refuses to run the image.

### Exercise 3 — `wrong-key`: an image signed with an untrusted key is rejected

```
./scripts/demo.sh wrong-key
```

Generates a new pair of signing keys in `keys/` (`scripts/gen-keys.sh`), then builds
`app/upgrade_probe` signed with those keys instead of the ones the device trusts
(`conf/own-keys.conf` selects them).

What to look for: the same rejection as in exercise 2. The image is well formed and
correctly signed — just not by a key the device trusts.

### Exercise 4 — `upgrade-ignored`: an upgrade that is not confirmed is skipped

```
./scripts/demo.sh upgrade-ignored
```

Builds `app/upgrade_probe` twice, as version 1 and version 2. Version 1 goes into the
active (primary) slot; version 2 is placed in the upgrade (secondary) slot, but
**without** setting the `image_ok` flag.

What to look for: `upgrade probe: APP VERSION 1`. The bootloader ignores the new image
without any error message.

### Exercise 5 — `upgrade-applied`: a confirmed upgrade is installed

```
./scripts/demo.sh upgrade-applied
```

Same as exercise 4, but with the `image_ok` flag set on the staged image.

What to look for: `Swap type: perm`, then the bootloader copies the secondary slot to
the primary slot and boots `upgrade probe: APP VERSION 2`.

### Run everything

```
./scripts/demo.sh all
```

Runs the five exercises in order.

## Repository contents

| Path | What it is |
|---|---|
| `app/upgrade_probe/` | Small app that prints its version; used in exercises 3–5 |
| `app/hello_signed/` | App that reads and prints its own image header, hash and signature |
| `app/psa_persistence/` | Checks that protected storage survives a reset |
| `conf/own-keys.conf` | Build option to sign with the keys in `keys/` |
| `docker/` | Docker image definition |
| `scripts/dev.sh` | Runs a command (or a shell) in the container |
| `scripts/demo.sh` | Runs the exercises |
| `scripts/qemu.sh` | Boots a `.hex` file in QEMU |
| `scripts/hexlab.py` | Modifies `.hex` images (tamper, stage upgrade, set `image_ok`) |
| `scripts/gen-keys.sh` | Generates new signing keys in `keys/` |
| `docker/west.yml` | Zephyr version and modules downloaded into the image |

## Troubleshooting

**`error: docker image zephyr-sb:3.7.2 not found`** — the image was not built, or was
built with a different name. Repeat step 2.

**`permission denied` from Docker** — your user is not allowed to use Docker. Run
`sudo usermod -aG docker $USER`, then log out and back in.
