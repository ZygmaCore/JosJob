#!/usr/bin/env bash
# =============================================================================
# Entry point cron — deploy otomatis JosJob dev (00:00 & 12:00 WIB).
#
# Crontab (dipasang oleh scripts/install-cron.sh):
#   0 1,13 * * * /home/mzkrl/JosJob/deploy-cron.sh >> /home/mzkrl/JosJob/cron-deploy.log 2>&1
#
# 00:00 & 12:00 WIB = 01:00 & 13:00 waktu server (Asia/Shanghai/UTC+8),
# karena cron Debian di server ini tidak mendukung CRON_TZ.
#
# Tugas wrapper:
#   1. Menyiapkan environment minimal cron (PATH, XDG_RUNTIME_DIR supaya
#      `systemctl --user` untuk cloudflared-dev tetap jalan).
#   2. Mencegah deploy tumpang-tindih dengan flock.
#   3. Menjalankan deploy-dev.sh, lalu melapor ke Discord hanya kalau script
#      itu mati sebelum sempat mengirim notifikasinya sendiri.
# =============================================================================
set -uo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"
UID_NOW="$(id -u)"

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
export HOME="${HOME:-/home/mzkrl}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID_NOW}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export TRIGGER="${TRIGGER:-cron}"
export BRANCH="${BRANCH:-dev}"

now() { printf '%s (WIB %s)' "$(date '+%F %T %Z')" "$(TZ=Asia/Jakarta date '+%F %T')"; }

# Log ringkas milik wrapper (output lengkap deploy ada di deploy-dev.log).
CRON_LOG="${CRON_LOG:-$REPO_DIR/cron-deploy.log}"
if [ -f "$CRON_LOG" ] && [ "$(stat -c %s "$CRON_LOG")" -gt 5242880 ]; then
  mv -f "$CRON_LOG" "$CRON_LOG.1"
fi
say() {
  if [ -t 1 ]; then
    printf '%s %s\n' "$(now)" "$*" | tee -a "$CRON_LOG"
  else
    # Di cron, stdout sudah diarahkan ke $CRON_LOG; tulis sekali saja.
    printf '%s %s\n' "$(now)" "$*" >>"$CRON_LOG"
  fi
}

cd "$REPO_DIR" || {
  echo "$(now) repo tidak ditemukan: $REPO_DIR" >&2
  exit 1
}

RUN_ID="cron-$(date +%Y%m%d-%H%M%S)"
export RUN_ID
MARKER="/tmp/josjob-notify-${RUN_ID}.done"
rm -f "$MARKER"

report_fallback() {
  local status="$1" code="$2" step="$3" detail="$4"
  # Lampirkan log hanya kalau memang baru ditulis run ini (< 10 menit),
  # supaya SKIPPED / run yang mati super awal tidak mengirim log basi.
  local attach=""
  if [ "$status" != "SKIPPED" ] && [ -f "$REPO_DIR/deploy-dev.log" ] &&
    [ -n "$(find "$REPO_DIR/deploy-dev.log" -mmin -10 2>/dev/null)" ]; then
    attach="$REPO_DIR/deploy-dev.log"
  fi
  STATUS="$status" \
    STEP="$step" \
    EXIT_CODE="$code" \
    DURATION="-" \
    BRANCH="$BRANCH" \
    COMMIT="$(git log -1 --format='%h %s' 2>/dev/null || echo '-')" \
    TRIGGER="$TRIGGER" \
    DETAIL="$detail" \
    RUN_ID="$RUN_ID" \
    ATTACH_LOG="$attach" \
    ATTACH_NAME="deploy-${RUN_ID}.log" \
    REPO_DIR="$REPO_DIR" \
    "$REPO_DIR/scripts/notify-discord.sh" || true
}

# --- Lock: jangan tumpuk deploy kalau yang sebelumnya belum selesai --------
LOCK_FILE="/tmp/josjob-deploy.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  say "Deploy sebelumnya masih berjalan — jadwal ini dilewati."
  report_fallback SKIPPED 0 "lock" \
    "Jadwal cron tiba, tapi deploy sebelumnya masih berjalan (flock aktif di $LOCK_FILE)."
  exit 0
fi

say "Mulai deploy via cron (RUN_ID=$RUN_ID)"
# Output lengkap sudah ditangkap deploy-dev.log lewat `tee`. Saat dijalankan
# cron (bukan TTY), jangan duplikasi ke cron-deploy.log; saat manual, tampilkan.
if [ -t 1 ]; then
  "$REPO_DIR/deploy-dev.sh"
  status=$?
else
  "$REPO_DIR/deploy-dev.sh" >/dev/null 2>&1
  status=$?
fi
say "deploy-dev.sh selesai dengan exit $status"

# deploy-dev.sh selalu kirim notifikasi lewat EXIT trap (dan menandai marker).
# Kalau exit != 0 tapi marker tidak ada, berarti script mati sebelum trap
# terpasang (file hilang, tidak executable, env gagal di-load) — wrapper yang
# melapor supaya tidak ada deploy gagal yang senyap.
if [ "$status" -ne 0 ] && [ ! -f "$MARKER" ]; then
  detail="deploy-dev.sh berhenti (exit $status) tanpa mengirim notifikasi sendiri — kemungkinan file hilang, tidak executable, atau gagal memuat envs/deploy.env."
  if [ -s "$REPO_DIR/deploy-dev.log" ]; then
    detail="$detail

$(tail -n 15 "$REPO_DIR/deploy-dev.log")"
  fi
  report_fallback FAILED "$status" "startup" "$detail"
fi

# Bersihkan marker notifikasi run lama (biar /tmp tidak menumpuk).
find /tmp -maxdepth 1 -name 'josjob-notify-*.done' -mtime +1 -delete 2>/dev/null || true

exit "$status"