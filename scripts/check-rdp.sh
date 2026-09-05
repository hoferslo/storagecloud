#!/bin/sh
set -eu

env \
  -u GIO_MODULE_DIR \
  -u GIO_LAUNCHED_DESKTOP_FILE \
  -u GIO_LAUNCHED_DESKTOP_FILE_PID \
  -u GTK_EXE_PREFIX \
  -u GTK_IM_MODULE_FILE \
  -u GTK_PATH \
  -u SNAP \
  -u SNAP_ARCH \
  -u SNAP_COMMON \
  -u SNAP_CONTEXT \
  -u SNAP_COOKIE \
  -u SNAP_DATA \
  -u SNAP_EUID \
  -u SNAP_INSTANCE_NAME \
  -u SNAP_LAUNCHER_ARCH_TRIPLET \
  -u SNAP_LIBRARY_PATH \
  -u SNAP_NAME \
  -u SNAP_REAL_HOME \
  -u SNAP_REVISION \
  -u SNAP_UID \
  -u SNAP_USER_COMMON \
  -u SNAP_USER_DATA \
  -u SNAP_VERSION \
  XDG_DATA_HOME=/home/gasper/.local/share \
  XDG_DATA_DIRS=/usr/share/ubuntu:/usr/share/gnome:/usr/local/share/:/usr/share/:/var/lib/snapd/desktop \
  XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  XDG_RUNTIME_DIR=/run/user/1000 \
  DISPLAY=:0 \
  WAYLAND_DISPLAY=wayland-0 \
  grdctl status --show-credentials

ss -tlnp 2>/dev/null | rg ':3389\b|State' || true
