#!/usr/bin/env bash
#
# asus-x1404va-numberpad-linux — automated, telemetry-free installer
# for the ASUS Vivobook X1404VA NumberPad on Linux (Ubuntu/Debian).
#
# It wraps the upstream driver
#   asus-linux-drivers/asus-numberpad-driver  (GPL-2.0)
# by downloading a pinned release and installing it non-interactively with the
# correct layout, groups, udev rules and systemd user service — and WITHOUT the
# upstream installer's interactive prompts and anonymous telemetry.
#
# Usage:   ./install.sh
# Options (environment variables):
#   LAYOUT=<name>        touchpad layout (default: e210ma — X1404VA / 093A:200B)
#   UPSTREAM_REF=<tag>   upstream release to install (default: v7.0.1)
#   INSTALL_DIR=<path>   install prefix (default: /usr/share/asus-numberpad-driver)
#
set -euo pipefail

# ---- configuration -------------------------------------------------------
UPSTREAM_REPO="https://github.com/asus-linux-drivers/asus-numberpad-driver.git"
UPSTREAM_REF="${UPSTREAM_REF:-v7.0.1}"        # pinned upstream release
LAYOUT="${LAYOUT:-e210ma}"                    # X1404VA / touchpad 093A:200B
INSTALL_DIR="${INSTALL_DIR:-/usr/share/asus-numberpad-driver}"
EXPECTED_TOUCHPAD_ID="093A:200B"

# ---- pretty output -------------------------------------------------------
c()    { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[0;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

# ---- preflight -----------------------------------------------------------
[ "${EUID:-$(id -u)}" -ne 0 ] || die "Do NOT run as root/sudo. Run as your normal user; the script calls sudo only when needed."
command -v sudo    >/dev/null || die "sudo is required."
command -v apt-get >/dev/null || die "This installer targets Ubuntu/Debian (apt). For other distros use the upstream installer."

USER_NAME="$(id -un)"
c "ASUS X1404VA NumberPad installer (upstream $UPSTREAM_REF, layout '$LAYOUT')"

# touchpad sanity check (non-fatal)
if grep -qi "Touchpad" /proc/bus/input/devices 2>/dev/null; then
  TP_LINE="$(grep -i "Touchpad" /proc/bus/input/devices | head -1)"
  if echo "$TP_LINE" | grep -qi "$EXPECTED_TOUCHPAD_ID"; then
    ok "Detected expected touchpad $EXPECTED_TOUCHPAD_ID."
  else
    warn "Touchpad id is not $EXPECTED_TOUCHPAD_ID:"
    warn "  $TP_LINE"
    warn "This repo targets the X1404VA. You may need a different LAYOUT (see README)."
    read -r -p "    Continue anyway? [y/N] " a; case "$a" in [yY]*) ;; *) exit 1 ;; esac
  fi
fi

# ---- 1. build dependencies ----------------------------------------------
c "Installing build dependencies (apt)…"
sudo apt-get update -qq
sudo apt-get install -y \
  ibus libevdev2 curl xinput i2c-tools git \
  python3-dev python3-venv libxml2-utils libxkbcommon-dev \
  gcc pkg-config libxcb-render0-dev libwayland-dev \
  libsystemd-dev python3-systemd
ok "Dependencies installed."

# ---- 2. groups + kernel modules -----------------------------------------
c "Setting up groups and kernel modules…"
for g in input i2c uinput numberpad; do sudo groupadd --system "$g" 2>/dev/null || true; done
sudo usermod -aG i2c,input,uinput,numberpad "$USER_NAME"
sudo modprobe uinput  || true   # built-in on some kernels; harmless if already present
sudo modprobe i2c-dev || true
printf 'uinput\ni2c-dev\n' | sudo tee /etc/modules-load.d/asus-numberpad.conf >/dev/null
ok "Groups ready; modules set to load at boot."

# ---- 3. udev rules -------------------------------------------------------
c "Installing udev rules for /dev/uinput and /dev/i2c-*…"
UINPUT_KERNEL=$(udevadm info --attribute-walk --name=/dev/uinput 2>/dev/null \
  | awk -F'==' '/KERNEL==/{gsub(/"/,"",$2);print $2;exit}')
UINPUT_SUBSYSTEM=$(udevadm info --attribute-walk --name=/dev/uinput 2>/dev/null \
  | awk -F'==' '/SUBSYSTEM==/{gsub(/"/,"",$2);print $2;exit}')
I2C_SUBSYSTEM=$(udevadm info --attribute-walk --name=/dev/i2c-0 2>/dev/null \
  | awk -F'==' '/SUBSYSTEM==/{gsub(/"/,"",$2);print $2;exit}')
: "${UINPUT_KERNEL:=uinput}"; : "${UINPUT_SUBSYSTEM:=misc}"; : "${I2C_SUBSYSTEM:=i2c-dev}"
echo "SUBSYSTEM==\"$UINPUT_SUBSYSTEM\", KERNEL==\"$UINPUT_KERNEL\", GROUP=\"uinput\", MODE=\"0660\"" \
  | sudo tee /usr/lib/udev/rules.d/99-asus-numberpad-driver-uinput.rules >/dev/null
echo "KERNEL==\"i2c-[0-9]*\", SUBSYSTEM==\"$I2C_SUBSYSTEM\", GROUP=\"i2c\", MODE=\"0660\"" \
  | sudo tee /usr/lib/udev/rules.d/99-asus-numberpad-driver-i2c-dev.rules >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --sysname-match=uinput          || true
sudo udevadm trigger --attr-match=subsystem=i2c-dev  || true
ok "udev rules installed."

# ---- 4. fetch upstream driver -------------------------------------------
c "Downloading upstream driver ($UPSTREAM_REF)…"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
git clone --quiet --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$BUILD_DIR/src"
[ -f "$BUILD_DIR/src/layouts/$LAYOUT.py" ] || die "Layout '$LAYOUT' not found in upstream $UPSTREAM_REF (see README for valid layouts)."
ok "Cloned upstream and verified layout '$LAYOUT'."

# ---- 5. install driver + python venv ------------------------------------
c "Installing driver to $INSTALL_DIR and building Python venv…"
sudo mkdir -p "$INSTALL_DIR/layouts"
sudo chown -R "$USER_NAME" "$INSTALL_DIR"
install "$BUILD_DIR/src/numberpad.py" "$INSTALL_DIR/"
install -t "$INSTALL_DIR/layouts" "$BUILD_DIR"/src/layouts/*.py

python3 -m venv "$INSTALL_DIR/.env"
"$INSTALL_DIR/.env/bin/pip" install --quiet --upgrade pip setuptools wheel
"$INSTALL_DIR/.env/bin/pip" install --quiet -r "$BUILD_DIR/src/requirements.txt"
"$INSTALL_DIR/.env/bin/pip" install --quiet -r "$BUILD_DIR/src/requirements.systemd.txt"

SESSION_TYPE="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^XDG_SESSION_TYPE=//p')"
: "${SESSION_TYPE:=${XDG_SESSION_TYPE:-wayland}}"
if [ "$SESSION_TYPE" = "wayland" ]; then
  "$INSTALL_DIR/.env/bin/pip" install --quiet -r "$BUILD_DIR/src/requirements.wayland.txt"
fi
ok "Driver installed; venv ready (session: $SESSION_TYPE)."

# ---- 6. systemd user service --------------------------------------------
c "Installing systemd user service…"
# Prefer values from the running graphical session, fall back to sane defaults.
getenv() { systemctl --user show-environment 2>/dev/null | sed -n "s/^$1=//p"; }
DISPLAY_V="$(getenv DISPLAY)";                 : "${DISPLAY_V:=${DISPLAY:-:0}}"
XRD="$(getenv XDG_RUNTIME_DIR)";               : "${XRD:=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}}"
DBUS_V="$(getenv DBUS_SESSION_BUS_ADDRESS)";   : "${DBUS_V:=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XRD/bus}}"

mkdir -p "$HOME/.config/systemd/user"
SERVICE_OUT="$HOME/.config/systemd/user/asus_numberpad_driver@.service"

if [ "$SESSION_TYPE" = "x11" ]; then
  XAUTH="$(getenv XAUTHORITY)"; : "${XAUTH:=${XAUTHORITY:-}}"
  INSTALL_DIR_PATH="$INSTALL_DIR" LAYOUT_NAME="$LAYOUT" CONFIG_FILE_DIR_PATH="$INSTALL_DIR/" \
  DISPLAY="$DISPLAY_V" XAUTHORITY="$XAUTH" XDG_RUNTIME_DIR="$XRD" XDG_SESSION_TYPE="$SESSION_TYPE" \
  DBUS_SESSION_BUS_ADDRESS="$DBUS_V" LOG_ENV_LINE="" \
    envsubst '$INSTALL_DIR_PATH $LAYOUT_NAME $CONFIG_FILE_DIR_PATH $DISPLAY $XAUTHORITY $XDG_RUNTIME_DIR $XDG_SESSION_TYPE $DBUS_SESSION_BUS_ADDRESS $LOG_ENV_LINE' \
    < "$BUILD_DIR/src/asus_numberpad_driver.x11.service" > "$SERVICE_OUT"
else
  INSTALL_DIR_PATH="$INSTALL_DIR" LAYOUT_NAME="$LAYOUT" CONFIG_FILE_DIR_PATH="$INSTALL_DIR/" \
  DISPLAY="$DISPLAY_V" XDG_RUNTIME_DIR="$XRD" XDG_SESSION_TYPE="$SESSION_TYPE" \
  DBUS_SESSION_BUS_ADDRESS="$DBUS_V" LOG_ENV_LINE="" \
    envsubst '$INSTALL_DIR_PATH $LAYOUT_NAME $CONFIG_FILE_DIR_PATH $DISPLAY $XDG_RUNTIME_DIR $XDG_SESSION_TYPE $DBUS_SESSION_BUS_ADDRESS $LOG_ENV_LINE' \
    < "$BUILD_DIR/src/asus_numberpad_driver.wayland.service" > "$SERVICE_OUT"
fi

systemctl --user daemon-reload
systemctl --user enable "asus_numberpad_driver@$USER_NAME.service" >/dev/null 2>&1 || true
ok "Service installed and enabled."

# ---- done ----------------------------------------------------------------
c "Installation complete."
cat <<EOF

  The NumberPad service is installed and will start automatically on login.

  >>> REBOOT (or log out and back in) to finish. <<<
  Your user just joined new groups (i2c, input, uinput, numberpad) and the
  running session must pick them up before the service can start.

  After reboot:
    - Tap-and-hold the top-RIGHT corner icon of the touchpad (~1s) to toggle
      the NumberPad. Slide from the top-LEFT corner to change LED brightness.

  Manage the service:
    systemctl --user status  asus_numberpad_driver@$USER_NAME.service
    systemctl --user restart asus_numberpad_driver@$USER_NAME.service

  Config (sensitivity, idle brightness, ...):
    $INSTALL_DIR/numberpad_dev

  Uninstall:
    ./uninstall.sh
EOF
