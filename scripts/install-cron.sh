#!/usr/bin/env bash
# =============================================================================
# Pasang / refresh crontab user untuk auto-deploy JosJob dev.
#
# Jalankan sebagai user mzkrl:
#   ./scripts/install-cron.sh            # pasang (00:00 & 12:00 WIB)
#   CRON_HOURS="1,13" ./scripts/install-cron.sh   # override jam server
#   ./scripts/install-cron.sh --print    # lihat isi yang akan dipasang
#
# 00:00 & 12:00 WIB = 01:00 & 13:00 server (Asia/Shanghai, UTC+8). Cron
# Debian tidak mendukung CRON_TZ, jadi jamnya dikonversi manual.
#
# Entry lama yang mengandung "josjob"/"deploy-cron.sh" akan diganti; entry
# lain milik user tetap dipertahankan.
# =============================================================================
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"
CRON_HOURS="${CRON_HOURS:-1,13}"
CRON_MINUTE="${CRON_MINUTE:-0}"
CRON_LOG="${CRON_LOG:-$REPO_DIR/cron-deploy.log}"
UID_NOW="$(id -u)"

[ -x "$REPO_DIR/deploy-cron.sh" ] || {
  echo "deploy-cron.sh tidak executable: $REPO_DIR/deploy-cron.sh" >&2
  exit 1
}

block="# >>> josjob-deploy >>> (dipasang oleh scripts/install-cron.sh)
# Auto-deploy JosJob dev: 00:00 & 12:00 WIB = $CRON_HOURS waktu server (Asia/Shanghai).
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
XDG_RUNTIME_DIR=/run/user/$UID_NOW
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_NOW/bus
$CRON_MINUTE $CRON_HOURS * * * $REPO_DIR/deploy-cron.sh >> $CRON_LOG 2>&1
# <<< josjob-deploy <<<"

if [ "${1:-}" = "--print" ]; then
  printf '%s\n' "$block"
  exit 0
fi

current="$(crontab -l 2>/dev/null || true)"
if [ -n "$current" ]; then
  backup="/tmp/crontab.$UID_NOW.$(date +%Y%m%d-%H%M%S).bak"
  printf '%s\n' "$current" >"$backup"
  echo "Backup crontab lama: $backup"
fi

# Buang blok JosJob lama (termasuk baris cron-nya), sisanya dipertahankan.
kept="$(printf '%s\n' "$current" | awk '
  /# >>> josjob-deploy >>>/ {skip = 1; next}
  /# <<< josjob-deploy <<</ {skip = 0; next}
  skip {next}
  /deploy-cron\.sh/ {next}
  {print}
')"

{
  if [ -n "${kept//[[:space:]]/}" ]; then
    printf '%s\n\n' "$kept"
  fi
  printf '%s\n' "$block"
} | crontab -

echo "Crontab terpasang. Jadwal server: $(printf '%s' "$CRON_MINUTE $CRON_HOURS") (WIB 00:00 & 12:00)"
echo "--- crontab -l ---"
crontab -l
