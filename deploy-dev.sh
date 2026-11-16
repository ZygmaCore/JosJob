#!/usr/bin/env bash
# =============================================================================
# Manual deploy — JosJob dev VPS
#
# Jalankan sebagai user mzkrl (JANGAN sudo ./deploy-dev.sh):
#   cd /home/mzkrl/JosJob
#   ./deploy-dev.sh
#
# Opsi:
#   SKIP_PULL=1   ./deploy-dev.sh   # sudah pull manual
#   SKIP_SEED=1   ./deploy-dev.sh   # skip seed
#   DEPLOY_FE=0   ./deploy-dev.sh   # backend saja
#   BRANCH=main   ./deploy-dev.sh   # branch lain
#
# Setiap hasil deploy (sukses maupun gagal) dikirim ke Discord webhook yang
# URL-nya dibaca dari envs/deploy.env (DISCORD_WEBHOOK_URL, tidak masuk repo).
# Dipakai juga oleh deploy-cron.sh untuk build otomatis 00:00 & 12:00 WIB.
# =============================================================================
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"
BRANCH="${BRANCH:-dev}"
ENV_FILE="envs/.env"
COMPOSE_ARGS=(-f docker-compose.fullstack.yml -f docker-compose.local.yml)
SKIP_PULL="${SKIP_PULL:-0}"
SKIP_SEED="${SKIP_SEED:-0}"
DEPLOY_FE="${DEPLOY_FE:-1}"
LOG_FILE="${LOG_FILE:-$REPO_DIR/deploy-dev.log}"
TRIGGER="${TRIGGER:-manual}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
START_EPOCH="$(date +%s)"
COMMIT_INFO=""
FAIL_DETAIL=""
STEP="preflight"

if [ "$(id -u)" -eq 0 ]; then
  echo "Jangan jalankan script ini sebagai root. Jalankan sebagai mzkrl; sudo dipakai internal." >&2
  exit 1
fi

cd "$REPO_DIR"

# Kredensial khusus deploy (mis. DISCORD_WEBHOOK_URL) — tidak masuk repo.
if [ -f envs/deploy.env ]; then
  set -a
  # shellcheck disable=SC1091
  . envs/deploy.env
  set +a
fi

# Rotasi log per run: file aktif selalu berisi run ini (dikirim utuh ke
# Discord sebagai attachment), run sebelumnya disimpan sebagai .1.
if [ -s "$LOG_FILE" ]; then
  mv -f "$LOG_FILE" "$LOG_FILE.1"
fi

# Simpan semua output ke file agar kegagalan bisa diperiksa setelahnya.
exec > >(tee -a "$LOG_FILE") 2>&1

# Pakai sudo hanya kalau user benar-benar punya akses Docker tanpa password.
# Kalau tidak ada akses sama sekali, DOCKER dibiarkan kosong dan preflight
# (setelah trap terpasang) yang akan berhenti dengan pesan jelas.
DOCKER=()
if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo -n docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi
# --progress plain: tampilkan output tiap langkah build (mix/deps/Rust),
# supaya build panjang tidak terlihat "hang" di UI progress ringkas.
COMPOSE=("${DOCKER[@]}" compose --progress plain --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}")

log() { printf '\n==> %s\n' "$*"; }

format_duration() {
  local s="$1"
  if [ "$s" -lt 60 ]; then
    printf '%ds' "$s"
  elif [ "$s" -lt 3600 ]; then
    printf '%dm %ds' $((s / 60)) $((s % 60))
  else
    printf '%dh %dm' $((s / 3600)) $(((s % 3600) / 60))
  fi
}

# Kirim hasil deploy ke Discord. Marker file dipakai deploy-cron.sh untuk tahu
# apakah run ini sudah melapor (biar tidak ada notifikasi ganda).
notify() {
  local status="$1" code="${2:-0}" detail="${3:-}"
  STATUS="$status" \
    STEP="$STEP" \
    EXIT_CODE="$code" \
    DURATION="$(format_duration $(($(date +%s) - START_EPOCH)))" \
    BRANCH="$BRANCH" \
    COMMIT="$COMMIT_INFO" \
    TRIGGER="$TRIGGER" \
    DETAIL="$detail" \
    RUN_ID="$RUN_ID" \
    ATTACH_LOG="$LOG_FILE" \
    ATTACH_NAME="deploy-${RUN_ID}.log" \
    REPO_DIR="$REPO_DIR" \
    "$REPO_DIR/scripts/notify-discord.sh" || true
  : >"/tmp/josjob-notify-${RUN_ID}.done"
}

on_exit() {
  local code="$1"
  trap - ERR
  if [ "$code" -eq 0 ]; then
    notify SUCCESS 0 ""
  else
    notify FAILED "$code" "$FAIL_DETAIL"
  fi
}

# Retry HTTP sampai 2xx; dipakai karena container `running` != app siap.
wait_http() {
  local url="$1" tries="${2:-30}" i
  for i in $(seq 1 "$tries"); do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "HTTP check failed after $((tries * 2))s: $url" >&2
  return 1
}

trap 'status=$?; FAIL_DETAIL="$(tail -n 40 "$LOG_FILE" 2>/dev/null)"; echo; echo "!!! DEPLOY GAGAL di step: ${STEP} (line $LINENO, exit $status)"; echo "!!! Log lengkap: $LOG_FILE"; echo "--- josjob_be logs ---"; "${COMPOSE[@]}" logs --tail=120 josjob_be || true; echo "--- josjob_fe logs (tanpa noise healthcheck) ---"; "${COMPOSE[@]}" logs --tail=80 josjob_fe 2>/dev/null | grep -v "GET / HTTP/1.1\" 200" | tail -n 20 || true; echo; echo "!!! Kalau build mati dengan exit 137: cek OOM:"; echo "    sudo dmesg -T | grep -iE \"oom|killed process\" | tail -n 5"' ERR
trap 'exit_code=$?; on_exit "$exit_code"; exit "$exit_code"' EXIT

# --- Guard disk -------------------------------------------------------------
# Build Flutter butuh beberapa GB sementara di VPS 40 GB ini. Kalau ruang
# menipis, bersihkan image dangling dulu; build cache hanya dipangkas kalau
# benar-benar mepet, supaya rebuild tetap cepat.
free_kb() { df --output=avail -k / | tail -n 1 | tr -d ' '; }
if [ "$(free_kb)" -lt 3145728 ]; then
  log "Disk menipis (sisa $(df -h / | tail -n 1 | awk '{print $4}')) — prune image dangling"
  "${DOCKER[@]}" image prune -f || true
fi
if [ "$(free_kb)" -lt 2097152 ]; then
  log "Sisa < 2 GB — prune build cache yang tidak dipakai >24 jam"
  "${DOCKER[@]}" builder prune -f --filter until=24h || true
  log "Sisa disk sekarang: $(df -h / | tail -n 1 | awk '{print $4}')"
fi

if [ "${#DOCKER[@]}" -eq 0 ]; then
  echo "Tidak punya akses Docker tanpa password, dan sudo non-interaktif juga tidak tersedia." >&2
  echo "Perbaiki dengan:" >&2
  echo "  sudo usermod -aG docker $(id -un)   # lalu login ulang (atau: newgrp docker)" >&2
  echo "Cek: docker info" >&2
  exit 1
fi

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }
[ -f docker-compose.fullstack.yml ] && [ -f docker-compose.local.yml ] || {
  echo "Missing compose files (jalankan dari root repo)" >&2
  exit 1
}

log "Preflight"
df -h / | tail -n 1
free -h | sed -n '1,3p'
echo "Log: $LOG_FILE"

if [ "$SKIP_PULL" != "1" ]; then
  STEP="git pull"
  log "Pull origin/$BRANCH"
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH"
fi

# Commit yang benar-benar di-deploy (dipakai di notifikasi Discord).
COMMIT_INFO="$(git log -1 --format='%h %s' 2>/dev/null || echo '-')"

STEP="start database"
log "Start database (paradedb)"
"${COMPOSE[@]}" up -d --wait paradedb

STEP="build backend"
log "Build backend (deployment/docker_elixir/Dockerfile.dev)"
log "Catatan: langkah deps.compile (Rust NIF xberg dari source) bisa 20-40 menit di VPS ini."
"${COMPOSE[@]}" build josjob_be

STEP="migrate"
log "Migrate database"
"${COMPOSE[@]}" run --rm josjob_be /app/bin/migrate

if [ "$SKIP_SEED" != "1" ]; then
  STEP="seed"
  log "Seed database (idempotent)"
  if ! "${COMPOSE[@]}" run --rm josjob_be /app/bin/seed; then
    echo "WARN: seed gagal, lanjut start server." >&2
  fi
fi

STEP="start backend"
log "Recreate backend"
"${COMPOSE[@]}" up -d --force-recreate --wait --wait-timeout 180 josjob_be

STEP="health check backend"
log "Verify local API (localhost:4000)"
wait_http http://localhost:4000/ 30

if [ "$DEPLOY_FE" = "1" ]; then
  STEP="build frontend"
  log "Build frontend"
  "${COMPOSE[@]}" build josjob_fe

  STEP="start frontend"
  log "Recreate frontend"
  "${COMPOSE[@]}" up -d --force-recreate --wait --wait-timeout 180 josjob_fe
fi

STEP="cloudflared"
log "Ensure cloudflared-dev is running"
if ! systemctl --user is-active --quiet cloudflared-dev; then
  systemctl --user start cloudflared-dev || echo "WARN: gagal start cloudflared-dev" >&2
fi

STEP="health check public API"
log "Verify public API (api-dev.mzkrl.my.id)"
wait_http https://api-dev.mzkrl.my.id/ 30

if [ "$DEPLOY_FE" = "1" ]; then
  STEP="health check public frontend"
  log "Verify public frontend (dev.mzkrl.my.id)"
  wait_http https://dev.mzkrl.my.id/ 30
fi

STEP="done"
log "Deploy OK"
