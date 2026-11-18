#!/usr/bin/env bash
# =============================================================================
# Jalankan deploy-dev.sh di background, tahan logout SSH.
#
#   ./scripts/deploy-background.sh                 # langsung mulai (mode auto)
#   ./scripts/deploy-background.sh --full          # flag diteruskan ke deploy-dev.sh
#   WAIT_FOR_BUILD=1 ./scripts/deploy-background.sh --be
#
# Cara pakai yang disarankan (dikelola systemd user, tetap hidup setelah
# logout karena Linger=yes):
#
#   systemd-run --user --unit=josjob-deploy --collect \
#     --setenv=WAIT_FOR_BUILD=1 \
#     /home/mzkrl/JosJob/scripts/deploy-background.sh --full
#
# Pantau:
#   systemctl --user status josjob-deploy
#   journalctl --user -u josjob-deploy -f
#   tail -f /home/mzkrl/JosJob/deploy-dev.log
#
# Batalkan:
#   systemctl --user stop josjob-deploy
# =============================================================================
set -uo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"
cd "$REPO_DIR" || {
  echo "repo tidak ditemukan: $REPO_DIR" >&2
  exit 1
}

# Deploy tidak boleh jalan bareng build docker compose lain (mis. sisa
# `sudo docker compose build` di terminal lain): keduanya akan berebut RAM
# dan bikin VPS 2 GB ini swap-thrash.
if [ "${WAIT_FOR_BUILD:-0}" = "1" ]; then
  echo "Menunggu build docker compose lain selesai (Ctrl+C di terminal itu)..."
  for _ in $(seq 1 720); do
    pgrep -f 'docker compose .*build josjob_be' >/dev/null || break
    sleep 5
  done

  if pgrep -f 'docker compose .*build josjob_be' >/dev/null; then
    echo "Build lama masih jalan setelah 60 menit — deploy background dibatalkan." >&2
    STATUS=FAILED \
      STEP="wait for old build" \
      EXIT_CODE=1 \
      DURATION="60m" \
      BRANCH="${BRANCH:-dev}" \
      COMMIT="$(git log -1 --format='%h %s' 2>/dev/null || echo '-')" \
      TRIGGER="${TRIGGER:-manual}" \
      DETAIL="Deploy background menunggu build docker compose lama selesai selama 60 menit, tapi masih berjalan. Deploy dibatalkan supaya tidak berebut RAM." \
      REPO_DIR="$REPO_DIR" \
      "$REPO_DIR/scripts/notify-discord.sh" || true
    exit 1
  fi
fi

echo "Build lama sudah tidak ada. Mulai deploy..."

# Flag CLI (mis. --full, --plan, --be) diteruskan utuh ke deploy-dev.sh;
# deploy-dev.sh sendiri yang memvalidasi dan menampilkan --help.
DEPLOY_ARGS=("$@")
QUOTED_ARGS=""
for arg in "${DEPLOY_ARGS[@]}"; do
  printf -v q '%q' "$arg"
  QUOTED_ARGS="${QUOTED_ARGS:+$QUOTED_ARGS }$q"
done

# User manager systemd bisa punya daftar group yang basi (mis. baru saja
# ditambahkan ke group docker lewat usermod). `sg` membaca /etc/group, jadi
# pakai itu kalau docker belum bisa diakses langsung.
if ! docker info >/dev/null 2>&1; then
  if getent group docker | cut -d: -f4 | tr ',' '\n' | grep -qx "$(id -un)"; then
    echo "Akses docker lewat group belum aktif di sesi ini — re-exec via 'sg docker'."
    exec sg docker -c "exec '$REPO_DIR/deploy-dev.sh'${QUOTED_ARGS:+ $QUOTED_ARGS}"
  fi
fi

exec "$REPO_DIR/deploy-dev.sh" "${DEPLOY_ARGS[@]}"
