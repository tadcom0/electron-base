# balenaBlocks electron

This is work in progress

## What

Provides stuff that may be missing when running electron apps in kiosk mode
(with no desktop environment):
 * a wifi configuration dialog
 * a file picker
 * an on-screen keyboard (onboard)
 * a dialog for mounting / umounting removable drives

## Building

 Build and upload this project's docker images `./image-builder.sh`;

## Using

 * In your electron app project create a Dockerfile that uses this
 project: `FROM balenablocks/aarch64-balena-electron-env`,
 replace `aarch64` with the architecture you need (`aarch64`, `armv7hf` or `amd64`);
 * Put your electron app in `/usr/src/app` in this Dockerfile.

This works by running a window manager (`metacity` for now), `dbus`, an
on-screen keyboard (`onboard`) and requiring some js code before your
application.

The required js code replaces the file picker, adds buttons for opening the
additional dialogs and injects some javascript in each window to summon the
on-screen keyboard when an input is focused.

## Components

### Wifi configuration

Works by communicating with NetworkManager via DBus.

### File picker

Replaces the default electron gtk file picker, can be constrained with
`BALENAELECTRONJS_CONSTRAINT_PATH`.

### On-screen keyboard

`onboard` is summoned via the session dbus each time an input is focused.

### Mounting / umounting of removable drives

Watches and allows to mount / umount removable drives in
`BALENAELECTRONJS_MOUNTS_ROOT`.

## Environment variables:

| Name | Description | Default Value |
| ---- | ----------- | ------------- |
| `BALENAELECTRONJS_MOUNTS_ROOT` | Where the removable drives should be mounted| `/tmp/media` |
| `BALENAELECTRONJS_CONSTRAINT_PATH` | Only files in this path will be accessible through the file picker |  |
| `BALENAELECTRONJS_OVERLAY_DELAY` | Delay before showing the overlay icons | `200` |
| `BALENAELECTRONJS_REMOTE_DEBUGGING_PORT` | Enable electron remote debugging on this port |  |
| `BALENAELECTRONJS_SLEEP_BUTTON_POSITION` | Sleep button position: x,y |  |
| `BALENAELECTRONJS_WIFI_BUTTON_POSITION` | Wifi button position: x,y |  |
| `BALENAELECTRONJS_SETTINGS_BUTTON_POSITION` | Settings button position: x,y |  |
| `BALENAELECTRONJS_MOUNTS_BUTTON_POSITION` | Mounts button position: x,y |  |
| `BALENAELECTRONJS_SCREENSAVER_ON_COMMAND` | Shell command to run when the screensaver is turned on |  |
| `BALENAELECTRONJS_SCREENSAVER_OFF_COMMAND` | Shell command to run when the screensaver is turned off |  |
| `BALENAELECTRONJS_UPDATES_ONLY_DURING_SCREENSAVER` | Only allows application updates to happen while the screensaver is on if set |  |
| `BALENAELECTRONJS_SCREENSAVER_DELAY_OVERRIDE` | Overrides the screensaver delay from the settings: number in minutes or 'never' |  |
| `BALENAELECTRONJS_ZOOM_FACTOR` | Zoom factor for overlay windows size and position | `1` |
| `DBUS_SYSTEM_BUS_ADDRESS` | DBus address for communicating with NetworkManager | `unix:path=/host/run/dbus/system_bus_socket` |
| `XRANDR_ARGS` | Rotate the screen with `xrandr $XRANDR_ARGS`, example: "-o inverted -x" |  |
| `FORCE_FULLHD_30` | Force HDMI-2 output to 1920x1080@30Hz (workaround for GPU accel issues at 4K) |  |

## Remote methods:

Call them with `electron.ipcRenderer.invoke(methodName, ...parameters)` from any renderer process.

| Name | Parameters | Description |
| ---- | ---------- | ----------- |
| `mount-drive` | `drivePath: string` | Mounts all partitions of the drive, `drivePath` is the name of the drive in `/dev/disk/by-path/` |
| `disable-screensaver` | | Disables the screensaver, does not change the `sleepDelay` setting |
| `enable-screensaver` | | Enables the screensaver, does not change the `sleepDelay` setting |


## Utilities

 * [clicklock](https://github.com/zpfvo/clicklock) is available in `/usr/bin/clicklock` and will be run when the screensaver goes on

## GPU Rendering and balenaOS Version Notes

When upgrading balenaOS on Raspberry Pi (e.g., from 6.0.10+rev2 to 6.3.18), be aware of
changes that can affect Chrome/Electron GPU acceleration.

### Key changes between balenaOS 6.0.10 and 6.3.18

In `balena-raspberrypi` v6.1.24+rev5 (2025-01-23):

- **Default Linux kernel changed from 5.15 to 6.1** — The vc4 DRM driver received
  significant updates. CRTC naming changed from `pixelvalve-N` to `crtc-N`.
- **rpi-bootfiles updated to version 20241126** — Updated VideoCore firmware
  (`start*.elf`, `fixup*.dat`) which affects HDMI initialization and GPU memory.

No GPU/graphics-related changes were found in `meta-balena` itself for this version range.

### Resolution and GPU acceleration

The kernel change can affect HDMI mode selection. The older kernel (5.15) may auto-select
4K (3840x2160@30Hz) from the monitor's EDID, while kernel 6.1 may settle on 1080p. Running
at 4K creates a framebuffer ~3x larger (44MB vs 14MB) which can exceed the Pi 4 V3D GPU's
throughput and cause Chromium to fall back to software rendering.

**Diagnosis:** Compare the output of `dmesg | grep cma` and
`cat /sys/kernel/debug/dri/0/state` between working and non-working versions. Key things
to look for:

| | GPU accel works | GPU accel broken |
|---|---|---|
| Kernel | 6.1 (CRTCs named `crtc-N`) | 5.15 (CRTCs named `pixelvalve-N`) |
| CMA reserved | 327,680K (320MB) | 524,288K (512MB) |
| HDMI-2 resolution | 1920x1080 @ 60Hz | 3840x2160 @ 30Hz |
| Framebuffer size | 3200x1080 (13.8MB) | 5120x2160 (44.2MB) |

**Fix:** Since this project uses `vc4-kms-v3d` (full KMS), the legacy `hdmi_group`/`hdmi_mode`
config.txt settings are ignored. Resolution must be controlled via `xrandr` instead.

Set the `XRANDR_ARGS` environment variable to force a lower resolution, e.g.:

```
XRANDR_ARGS="--output HDMI-A-2 --mode 1920x1080"
```

Or to try 1440p:

```
XRANDR_ARGS="--output HDMI-A-2 --mode 2560x1440"
```

Note: the mode must be advertised by the monitor's EDID. Run `xrandr` on the device to
list available modes.
