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
# =============================================================================
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"
BRANCH="${BRANCH:-dev}"
ENV_FILE="envs/.env"
COMPOSE_ARGS=(-f docker-compose.fullstack.yml -f docker-compose.local.yml)
SKIP_PULL="${SKIP_PULL:-0}"
SKIP_SEED="${SKIP_SEED:-0}"
DEPLOY_FE="${DEPLOY_FE:-1}"

if [ "$(id -u)" -eq 0 ]; then
  echo "Jangan jalankan script ini sebagai root. Jalankan sebagai mzkrl; sudo dipakai internal." >&2
  exit 1
fi

cd "$REPO_DIR"

# Pakai sudo hanya kalau user belum punya akses Docker.
if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
else
  DOCKER=(sudo docker)
fi
COMPOSE=("${DOCKER[@]}" compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}")

log() { printf '\n==> %s\n' "$*"; }

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

trap 'echo; echo "--- josjob_be logs ---"; "${COMPOSE[@]}" logs --tail=120 josjob_be || true; echo "--- josjob_fe logs ---"; "${COMPOSE[@]}" logs --tail=60 josjob_fe || true' ERR

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }
[ -f docker-compose.fullstack.yml ] && [ -f docker-compose.local.yml ] || {
  echo "Missing compose files (jalankan dari root repo)" >&2
  exit 1
}

if [ "$SKIP_PULL" != "1" ]; then
  log "Pull origin/$BRANCH"
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH"
fi

log "Start database (paradedb)"
"${COMPOSE[@]}" up -d --wait paradedb

log "Build backend (deployment/docker_elixir/Dockerfile.dev)"
"${COMPOSE[@]}" build josjob_be

if [ "$DEPLOY_FE" = "1" ]; then
  log "Build frontend"
  "${COMPOSE[@]}" build josjob_fe
fi

log "Migrate database"
"${COMPOSE[@]}" run --rm josjob_be /app/bin/migrate

if [ "$SKIP_SEED" != "1" ]; then
  log "Seed database (idempotent)"
  if ! "${COMPOSE[@]}" run --rm josjob_be /app/bin/seed; then
    echo "WARN: seed gagal, lanjut start server." >&2
  fi
fi

log "Recreate backend"
"${COMPOSE[@]}" up -d --force-recreate --wait --wait-timeout 180 josjob_be

if [ "$DEPLOY_FE" = "1" ]; then
  log "Recreate frontend"
  "${COMPOSE[@]}" up -d --force-recreate --wait --wait-timeout 180 josjob_fe
fi

log "Ensure cloudflared-dev is running"
if ! systemctl --user is-active --quiet cloudflared-dev; then
  systemctl --user start cloudflared-dev || echo "WARN: gagal start cloudflared-dev" >&2
fi

log "Verify local API (localhost:4000)"
wait_http http://localhost:4000/ 30

log "Verify public API (api-dev.mzkrl.my.id)"
wait_http https://api-dev.mzkrl.my.id/ 30

if [ "$DEPLOY_FE" = "1" ]; then
  log "Verify public frontend (dev.mzkrl.my.id)"
  wait_http https://dev.mzkrl.my.id/ 30
fi

log "Deploy OK"
