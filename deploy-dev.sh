#!/usr/bin/env bash
# =============================================================================
# Deploy — JosJob dev VPS
#
# Jalankan sebagai user mzkrl (JANGAN sudo ./deploy-dev.sh):
#   cd /home/mzkrl/JosJob
#   ./deploy-dev.sh
#
# Deploy bersifat MODULAR: hanya komponen yang benar-benar berubah sejak deploy
# sukses terakhir yang di-build ulang. Commit terakhir per komponen disimpan di
# .deploy-state (gitignored), jadi kalau cuma UI yang berubah, backend tidak
# di-build sama sekali (dan sebaliknya).
#
# Opsi (semua lewat environment variable):
#   DEPLOY_MODE=auto|full  # auto (default) = hanya yang berubah, full = paksa semua
#   FORCE_BE=1             # paksa build backend
#   FORCE_FE=1             # paksa build frontend
#   SKIP_PULL=1            # sudah pull manual
#   SKIP_SEED=1            # skip seed
#   DEPLOY_FE=0            # backend saja (frontend tidak disentuh)
#   BRANCH=main            # branch lain
#
# Setiap hasil deploy (sukses, gagal, tidak ada perubahan, dibatalkan) dikirim
# ke Discord webhook yang URL-nya dibaca dari envs/deploy.env
# (DISCORD_WEBHOOK_URL, tidak masuk repo).
# =============================================================================
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"
BRANCH="${BRANCH:-dev}"
ENV_FILE="envs/.env"
COMPOSE_ARGS=(-f docker-compose.fullstack.yml -f docker-compose.local.yml)
SKIP_PULL="${SKIP_PULL:-0}"
SKIP_SEED="${SKIP_SEED:-0}"
DEPLOY_FE="${DEPLOY_FE:-1}"
DEPLOY_MODE="${DEPLOY_MODE:-auto}" # auto | full
FORCE_BE="${FORCE_BE:-0}"
FORCE_FE="${FORCE_FE:-0}"
LOG_FILE="${LOG_FILE:-$REPO_DIR/deploy-dev.log}"
STATE_FILE="${STATE_FILE:-$REPO_DIR/.deploy-state}"
TRIGGER="${TRIGGER:-manual}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
START_EPOCH="$(date +%s)"
COMMIT_INFO=""
FAIL_DETAIL=""
PLAN=""
BE_IMAGE="josjob-backend:local"
FE_IMAGE="josjob-fe:local"
BE_NEEDED=1
FE_NEEDED=1
NO_CHANGES=0
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

# --- State deploy (commit terakhir yang sukses per komponen) ----------------
state_get() {
  local key="$1"
  [ -f "$STATE_FILE" ] || return 0
  sed -n "s/^${key}=//p" "$STATE_FILE" | tail -n 1
}

state_set() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
  if [ -f "$STATE_FILE" ]; then
    grep -v "^${key}=" "$STATE_FILE" >"$tmp" || true
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

image_exists() { "${DOCKER[@]}" image inspect "$1" >/dev/null 2>&1; }

# true kalau ada perubahan pada <pathspec...> antara <base> dan <head>.
# Base kosong / tidak dikenal (mis. setelah force-push) -> anggap berubah.
path_changed() {
  local base="$1" head="$2"
  shift 2
  [ -n "$base" ] || return 0
  git cat-file -e "${base}^{commit}" 2>/dev/null || return 0
  if git diff --quiet "$base" "$head" -- "$@" 2>/dev/null; then
    return 1
  fi
  return 0
}

# Nilai dari envs/.env (dipakai untuk build args FE; compose juga membacanya).
env_file_value() {
  local key="$1" line
  [ -f "$ENV_FILE" ] || return 0
  line="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 || true)"
  [ -n "$line" ] || return 0
  printf '%s' "${line#*=}" | sed -e 's/^["'\'']//' -e 's/["'\'']$//'
}

# FE dibakar saat build (Dart String.fromEnvironment), jadi kalau build args di
# envs/.env berubah FE harus di-build ulang walau kodenya sama.
fe_args_fingerprint() {
  printf '%s|%s' "$(env_file_value API_BASE_URL)" "$(env_file_value GOOGLE_CLIENT_ID)" |
    sha256sum | cut -c1-16
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

# --- Notifikasi Discord -----------------------------------------------------
# Marker file dipakai deploy-cron.sh untuk tahu apakah run ini sudah melapor
# (biar tidak ada notifikasi ganda).
notify() {
  local status="$1" code="${2:-0}" detail="${3:-}"
  STATUS="$status" \
    STEP="$STEP" \
    EXIT_CODE="$code" \
    DURATION="$(format_duration $(($(date +%s) - START_EPOCH)))" \
    BRANCH="$BRANCH" \
    COMMIT="$COMMIT_INFO" \
    TRIGGER="$TRIGGER" \
    PLAN="$PLAN" \
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
  trap - ERR TERM INT
  if [ "$code" -eq 0 ]; then
    if [ "$NO_CHANGES" = "1" ]; then
      notify NOCHANGES 0 ""
    else
      notify SUCCESS 0 ""
    fi
  elif [ "$code" -eq 130 ] || [ "$code" -eq 143 ]; then
    notify ABORTED "$code" "Deploy dihentikan (SIGINT/SIGTERM) saat step: $STEP."
  else
    notify FAILED "$code" "$FAIL_DETAIL"
  fi
}

# Trap ERR WAJIB mengakhiri script. Kalau tidak, bash menganggap kegagalan
# sudah "ditangani" (perintah terakhir di trap sukses) dan deploy bisa
# dilaporkan SUCCESS walau build sebenarnya mati di tengah jalan.
on_error() {
  local status=$?
  trap - ERR
  FAIL_DETAIL="$(tail -n 40 "$LOG_FILE" 2>/dev/null || true)"
  echo
  echo "!!! DEPLOY GAGAL di step: ${STEP} (exit $status)"
  echo "!!! Log lengkap: $LOG_FILE"
  echo "--- josjob_be logs ---"
  "${COMPOSE[@]}" logs --tail=120 josjob_be || true
  echo "--- josjob_fe logs (tanpa noise healthcheck) ---"
  "${COMPOSE[@]}" logs --tail=80 josjob_fe 2>/dev/null | grep -v 'GET / HTTP/1.1" 200' | tail -n 20 || true
  echo
  echo "!!! Kalau build mati dengan exit 137: cek OOM:"
  echo "    sudo dmesg -T | grep -iE \"oom|killed process\" | tail -n 5"
  exit "$status"
}

trap on_error ERR
trap 'echo; echo "Dibatalkan (SIGTERM)."; exit 143' TERM
trap 'echo; echo "Dibatalkan (SIGINT)."; exit 130' INT
trap 'exit_code=$?; on_exit "$exit_code"; exit "$exit_code"' EXIT

# --- Preflight --------------------------------------------------------------
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

# --- Guard disk -------------------------------------------------------------
# Build Flutter butuh beberapa GB sementara di VPS 40 GB ini. Kalau ruang
# menipis, bersihkan image dangling dulu; build cache hanya dipangkas kalau
# benar-benar mepet, supaya rebuild berikutnya tetap cepat.
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

log "Preflight"
df -h / | tail -n 1
free -h | sed -n '1,3p'
echo "Log: $LOG_FILE"

# --- Ambil kode terbaru -----------------------------------------------------
if [ "$SKIP_PULL" != "1" ]; then
  STEP="git pull"
  log "Pull origin/$BRANCH"
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH"
fi

# Commit yang benar-benar di-deploy (dipakai di notifikasi Discord).
COMMIT_INFO="$(git log -1 --format='%h %s' 2>/dev/null || echo '-')"
HEAD_SHA="$(git rev-parse HEAD)"
BE_SHA="$(state_get BE_SHA)"
FE_SHA="$(state_get FE_SHA)"

# --- Tentukan apa yang perlu di-build --------------------------------------
BE_PATHS=(
  apps ":(exclude)apps/josjob_fe"
  mix.exs mix.lock config rel
  deployment/docker_elixir/Dockerfile.dev
  docker-compose.fullstack.yml docker-compose.local.yml
)
FE_PATHS=(apps/josjob_fe docker-compose.fullstack.yml)

if [ "$DEPLOY_MODE" = "full" ]; then
  BE_NEEDED=1
  FE_NEEDED=1
else
  if path_changed "$BE_SHA" "$HEAD_SHA" "${BE_PATHS[@]}"; then BE_NEEDED=1; else BE_NEEDED=0; fi
  if path_changed "$FE_SHA" "$HEAD_SHA" "${FE_PATHS[@]}"; then FE_NEEDED=1; else FE_NEEDED=0; fi
  if [ "$(state_get FE_ARGS)" != "$(fe_args_fingerprint)" ]; then
    echo "Build args FE berubah (API_BASE_URL/GOOGLE_CLIENT_ID) — frontend di-build ulang."
    FE_NEEDED=1
  fi
fi
[ "$FORCE_BE" = "1" ] && BE_NEEDED=1
[ "$FORCE_FE" = "1" ] && FE_NEEDED=1
[ "$DEPLOY_FE" = "1" ] || FE_NEEDED=0

# Image bisa hilang kalau di-prune manual; kalau begitu wajib build.
if [ "$BE_NEEDED" = "0" ] && ! image_exists "$BE_IMAGE"; then
  echo "Image $BE_IMAGE tidak ada — backend tetap di-build."
  BE_NEEDED=1
fi
if [ "$FE_NEEDED" = "0" ] && ! image_exists "$FE_IMAGE"; then
  echo "Image $FE_IMAGE tidak ada — frontend tetap di-build."
  FE_NEEDED=1
fi

if [ "$BE_NEEDED" = "1" ]; then be_plan="build"; else be_plan="reuse ($BE_IMAGE)"; fi
if [ "$DEPLOY_FE" != "1" ]; then
  fe_plan="skip (DEPLOY_FE=0)"
elif [ "$FE_NEEDED" = "1" ]; then
  fe_plan="build"
else
  fe_plan="reuse ($FE_IMAGE)"
fi
PLAN="backend: $be_plan · frontend: $fe_plan"

log "Rencana deploy (mode $DEPLOY_MODE)"
echo "  HEAD           : ${COMMIT_INFO}"
echo "  backend        : $be_plan  (terakhir sukses: ${BE_SHA:-belum pernah})"
echo "  frontend       : $fe_plan  (terakhir sukses: ${FE_SHA:-belum pernah})"

# --- Database ---------------------------------------------------------------
STEP="start database"
log "Start database (paradedb)"
"${COMPOSE[@]}" up -d --wait paradedb

# --- Backend ----------------------------------------------------------------
if [ "$BE_NEEDED" = "1" ]; then
  STEP="build backend"
  log "Build backend (deployment/docker_elixir/Dockerfile.dev)"
  log "NIF xberg dipakai dari binary prebuilt — build normal hitungan menit, bukan puluhan menit."
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

  state_set BE_SHA "$HEAD_SHA"
else
  STEP="start backend"
  log "Backend tidak berubah — image $BE_IMAGE dipakai ulang (tanpa rebuild)"
  # Tanpa --build: kalau config/env berubah, compose tetap recreate sendiri.
  "${COMPOSE[@]}" up -d --wait --wait-timeout 120 josjob_be
fi

# --- Frontend ---------------------------------------------------------------
if [ "$FE_NEEDED" = "1" ]; then
  STEP="build frontend"
  log "Build frontend"
  "${COMPOSE[@]}" build josjob_fe

  STEP="start frontend"
  log "Recreate frontend"
  "${COMPOSE[@]}" up -d --force-recreate --wait --wait-timeout 180 josjob_fe

  state_set FE_SHA "$HEAD_SHA"
  state_set FE_ARGS "$(fe_args_fingerprint)"
elif [ "$DEPLOY_FE" = "1" ]; then
  STEP="start frontend"
  log "Frontend tidak berubah — image $FE_IMAGE dipakai ulang (tanpa rebuild)"
  "${COMPOSE[@]}" up -d --wait --wait-timeout 120 josjob_fe
fi

# --- Health check akhir -----------------------------------------------------
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
if [ "$BE_NEEDED" = "0" ] && [ "$FE_NEEDED" = "0" ] && [ "$DEPLOY_MODE" = "auto" ]; then
  NO_CHANGES=1
  log "Deploy OK — tidak ada perubahan kode sejak deploy terakhir, semua service tetap jalan"
else
  log "Deploy OK"
fi
