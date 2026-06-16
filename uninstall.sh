#!/usr/bin/env bash
#
# Uninstaller for asus-x1404va-numberpad-linux.
# Removes the driver, systemd user service, udev rules and module-load config.
# Groups (i2c/input/uinput/numberpad) are left in place; remove them manually
# if you want a fully clean state.
#
set -uo pipefail

INSTALL_DIR="${INSTALL_DIR:-/usr/share/asus-numberpad-driver}"
USER_NAME="$(id -un)"

[ "${EUID:-$(id -u)}" -ne 0 ] || { echo "Run as your normal user, not root."; exit 1; }

echo "==> Stopping and disabling the service…"
systemctl --user stop    "asus_numberpad_driver@$USER_NAME.service" 2>/dev/null || true
systemctl --user disable "asus_numberpad_driver@$USER_NAME.service" 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/asus_numberpad_driver@.service"
systemctl --user daemon-reload 2>/dev/null || true

echo "==> Removing driver files ($INSTALL_DIR)…"
sudo rm -rf "$INSTALL_DIR"

echo "==> Removing udev rules and module-load config…"
sudo rm -f /usr/lib/udev/rules.d/99-asus-numberpad-driver-uinput.rules
sudo rm -f /usr/lib/udev/rules.d/99-asus-numberpad-driver-i2c-dev.rules
sudo rm -f /etc/modules-load.d/asus-numberpad.conf
sudo udevadm control --reload-rules 2>/dev/null || true

echo "==> Done. Groups i2c/input/uinput/numberpad were kept (remove manually if desired)."
echo "    A reboot is recommended."
