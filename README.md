# ASUS Vivobook X1404VA — NumberPad driver for Linux

🇧🇷 **[Leia em português »](README.pt-BR.md)**

Enable the **NumberPad** (the illuminated numeric keypad built into the
touchpad, with an on/off icon in the top-right corner) on the **ASUS Vivobook
X1404VA** under Linux.

ASUS only ships this feature for Windows. On Linux there is no kernel driver —
it works through a user-space daemon. This repository is a thin, **automated,
telemetry-free installer** around the excellent upstream driver
[`asus-linux-drivers/asus-numberpad-driver`](https://github.com/asus-linux-drivers/asus-numberpad-driver)
(GPL-2.0). It picks the right layout for the X1404VA, sets up groups, udev rules
and a systemd user service, and skips the upstream installer's interactive
prompts and anonymous reporting.

## Why this repo instead of the upstream installer?

The upstream project supports dozens of laptops and its installer is fully
interactive (layout menus, optional features, anonymous telemetry prompts).
This wrapper:

- ✅ **Non-interactive** — one command, no menus.
- ✅ **No telemetry** — never sends any anonymous report.
- ✅ **Right layout out of the box** — `e210ma`, matching the X1404VA touchpad.
- ✅ **Idempotent** — safe to re-run.
- ✅ **Pinned upstream release** for reproducible installs.

It does **not** fork or copy the driver: it downloads a pinned upstream release
at install time, so you still get upstream's fixes and full credit stays with
them.

## Supported hardware

Primary target: **ASUS Vivobook X1404VA** (touchpad `093A:200B`, layout
`e210ma`).

The **same touchpad + layout** also covers these models (they should work with
the default settings):

| Model | Touchpad ID | Layout |
|-------|-------------|--------|
| Vivobook X1404VA / X1404VAP / X1404VAPF | `093A:200B` | `e210ma` |
| Vivobook X1404ZA | `093A:200B` | `e210ma` |
| Vivobook Go E1404FA / E1404GA | `093A:200B` | `e210ma` |
| ExpertBook B1403CVA | `093A:200B` | `e210ma` |

Have a different ASUS model? See [Using a different layout](#using-a-different-layout).

## Requirements

- **Ubuntu / Debian** (or derivatives that use `apt`).
- A graphical session — **Wayland or X11** (auto-detected).
- `sudo` privileges.

> Tested on Ubuntu 26.04 (kernel 7.x, Python 3.14), Wayland/GNOME.

## Install

```bash
git clone https://github.com/<your-user>/asus-x1404va-numberpad-linux.git
cd asus-x1404va-numberpad-linux
./install.sh
```

Then **reboot** (or log out and back in). The reboot is required so your user
session picks up the new groups (`i2c`, `input`, `uinput`, `numberpad`) before
the service starts.

## Usage

After rebooting:

- **Toggle the NumberPad:** tap and hold (~1 second) the **icon in the
  top-right corner** of the touchpad. The numbers light up; the touchpad area
  becomes a numeric keypad. Tap-and-hold again to turn it off.
- **Adjust LED brightness:** slide from the **top-left corner** inward.

## Managing the service

```bash
# status / restart / stop
systemctl --user status  asus_numberpad_driver@$USER.service
systemctl --user restart asus_numberpad_driver@$USER.service
systemctl --user stop    asus_numberpad_driver@$USER.service

# live logs (troubleshooting)
journalctl --user -u asus_numberpad_driver@$USER.service -f
```

## Configuration

A config file is auto-created on first run at:

```
/usr/share/asus-numberpad-driver/numberpad_dev
```

There you can tune sensitivity, idle brightness, key-repeat, the top-corner
gestures and more. Restart the service after editing.

## Using a different layout

The installer accepts environment variables:

```bash
# pick another layout (see upstream `layouts/` for the full list)
LAYOUT=up5401ea ./install.sh

# pin a different upstream release
UPSTREAM_REF=v7.0.1 ./install.sh
```

To find your touchpad ID:

```bash
grep -i touchpad /proc/bus/input/devices
```

The available layouts live in the upstream repo under
[`layouts/`](https://github.com/asus-linux-drivers/asus-numberpad-driver/tree/master/layouts).

## Uninstall

```bash
./uninstall.sh
```

This stops/disables the service and removes the driver, udev rules and
module-load config. The groups are kept (remove them manually if you want a
fully clean state).

## How it works

`install.sh`:

1. Installs build dependencies via `apt`.
2. Creates the `i2c`/`input`/`uinput`/`numberpad` groups, adds your user, and
   loads + persists the `uinput` and `i2c-dev` modules.
3. Installs udev rules granting your user access to `/dev/uinput` and
   `/dev/i2c-*`.
4. Downloads the pinned upstream release, copies `numberpad.py` + layouts to
   `/usr/share/asus-numberpad-driver`, and builds an isolated Python venv.
5. Generates a systemd **user** service (Wayland or X11 template) with the
   `e210ma` layout — and **no** telemetry.

## Credits

All the real work is done by the upstream driver:
**[asus-linux-drivers/asus-numberpad-driver](https://github.com/asus-linux-drivers/asus-numberpad-driver)**
(GPL-2.0). Please ⭐ and support them.

This wrapper only automates a clean, telemetry-free install for the X1404VA.

## License

The scripts in this repository are released under the [MIT License](LICENSE).
The downloaded upstream driver remains under its own GPL-2.0 license.
