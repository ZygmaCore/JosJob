#!/usr/bin/env bash
# =============================================================================
# Deploy — JosJob dev VPS
#
# Jalankan sebagai user mzkrl (JANGAN sudo ./deploy-dev.sh):
#   cd /home/mzkrl/JosJob
#   ./deploy-dev.sh
#
# Deploy bersifat MODULAR: hanya komponen yang benar-benar berubah sejak deploy
# sukses terakhir yang di-build ulang. Deteksinya DINAMIS: build context tiap
# service dibaca dari compose (bukan hardcode nama folder), lalu file yang
# berubah disaring pakai `.dockerignore` milik context itu — sama seperti Docker
# menentukan apa yang ikut build. Jadi rename app / tambah app / pindah context
# tetap terdeteksi benar.
#
# State disimpan per-host di .deploy-state (gitignored): commit terakhir yang
# sukses per komponen. Mesin yang belum punya file ini akan build semua
# (aman). Hapus file itu, atau pakai DEPLOY_MODE=full, untuk memaksa full deploy.
#
# Opsi (semua lewat environment variable):
#   DEPLOY_MODE=auto|full  # auto (default) = hanya yang berubah, full = paksa semua
#   FORCE_BE=1             # paksa build backend
#   FORCE_FE=1             # paksa build frontend
#   PLAN_ONLY=1            # cuma tampilkan rencana build, tidak menyentuh Docker
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
PLAN_ONLY="${PLAN_ONLY:-0}"
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
# PLAN_ONLY tidak menyentuh log deploy.
if [ "$PLAN_ONLY" = "1" ]; then
  :
elif [ -s "$LOG_FILE" ]; then
  mv -f "$LOG_FILE" "$LOG_FILE.1"
fi

# Simpan semua output ke file agar kegagalan bisa diperiksa setelahnya.
if [ "$PLAN_ONLY" != "1" ]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

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

# --- Deteksi perubahan per service (dinamis, diturunkan dari compose) -------
# Nama folder/app TIDAK di-hardcode: build context tiap service dibaca dari
# compose, lalu file yang berubah disaring pakai `.dockerignore` milik context
# itu (sama seperti Docker sendiri). Jadi kalau app di-rename, app baru
# ditambah, atau context build dipindah, deteksi ikut menyesuaikan — aman
# untuk handoff ke repo/mesin lain.
COMPOSE_JSON=""

load_compose_contexts() {
  COMPOSE_JSON="$("${COMPOSE[@]}" config --format json 2>/dev/null || true)"
}

service_context() {
  local svc="$1"
  [ -n "$COMPOSE_JSON" ] || { printf '.'; return 0; }
  printf '%s' "$COMPOSE_JSON" |
    jq -r --arg svc "$svc" '.services[$svc].build.context // "."' 2>/dev/null ||
    printf '.'
}

service_dockerfile() {
  local svc="$1"
  [ -n "$COMPOSE_JSON" ] || return 1
  printf '%s' "$COMPOSE_JSON" |
    jq -r --arg svc "$svc" '.services[$svc].build.dockerfile // "Dockerfile"' 2>/dev/null
}

# Path absolut/relatif dari compose -> relatif terhadap root repo ("." = root).
ctx_rel() {
  local p="${1:-.}"
  p="${p#"$REPO_DIR"}"
  p="${p#/}"
  case "$p" in
    '' | './') printf '.' ;;
    ./*) printf '%s' "${p#./}" ;;
    *) printf '%s' "$p" ;;
  esac
}

# Path (relatif terhadap context) diabaikan .dockerignore?
# Semantik dockerignore: pola tanpa "/" hanya berlaku untuk komponen pertama
# path (root context), trailing "/" diabaikan, "!" = negasi.
ignored_by_dockerignore() {
  local dir="$1" path="$2" pat negate p first
  [ -f "$dir/.dockerignore" ] || return 1
  while IFS= read -r pat || [ -n "$pat" ]; do
    pat="${pat%$'\r'}"
    case "$pat" in '' | '#'*) continue ;; esac
    negate=0
    case "$pat" in
      '!'*)
        negate=1
        pat="${pat#!}"
        ;;
    esac
    p="${pat#/}"
    p="${p%/}"
    [ -n "$p" ] || continue

    if [[ "$p" != */* ]]; then
      # Pola root-level: cocokkan ke komponen pertama path saja.
      first="${path%%/*}"
      [[ "$first" == $p ]] || continue
    else
      [[ "$path" == $p || "$path" == $p/* ]] || continue
    fi

    [ "$negate" = "1" ] && return 1
    return 0
  done <"$dir/.dockerignore"
  return 1
}

# Source yang benar-benar di-COPY/ADD dari build context (relatif context).
# File di context yang tidak pernah di-COPY (mis. deploy-dev.sh, docs) tidak
# mengubah image, jadi tidak boleh memicu rebuild.
dockerfile_copy_sources() { # <service>
  local svc="$1" ctx dockerfile
  ctx="$(ctx_rel "$(service_context "$svc")")"
  dockerfile="$(service_dockerfile "$svc")" || return 1
  [ -f "$REPO_DIR/$ctx/$dockerfile" ] || return 1
  awk '
    /^[[:space:]]*(COPY|ADD)[[:space:]]/ {
      if ($0 ~ /--from=/) next
      line = $0
      sub(/^[[:space:]]*(COPY|ADD)[[:space:]]+/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      n = split(line, a, /[[:space:]]+/)
      for (i = 1; i < n; i++) {
        if (a[i] ~ /^--/) continue
        if (a[i] == "") continue
        print a[i]
      }
    }' "$REPO_DIR/$ctx/$dockerfile"
}

path_in_copy_sources() { # <path relatif context> <source...>
  local path="$1" src
  shift
  for src in "$@"; do
    case "$src" in
      . | ./) return 0 ;;
    esac
    src="${src#./}"
    src="${src%/}"
    if [[ "$path" == $src || "$path" == "$src"/* ]]; then
      return 0
    fi
  done
  return 1
}

# CHANGED_HINT diisi ringkasan file pemicu (untuk log/notifikasi).
CHANGED_HINT=""
service_changed() { # <base_sha> <head_sha> <service>
  local base="$1" _head="$2" svc="$3" ctx ctx_dir rel file list="" n dockerfile
  local filter_copy=0
  local -a sources=()
  CHANGED_HINT=""
  [ -n "$base" ] || return 0
  git cat-file -e "${base}^{commit}" 2>/dev/null || return 0
  ctx="$(ctx_rel "$(service_context "$svc")")"
  if [ "$ctx" = "." ]; then ctx_dir="$REPO_DIR"; else ctx_dir="$REPO_DIR/$ctx"; fi
  dockerfile="$(service_dockerfile "$svc" 2>/dev/null || echo Dockerfile)"
  mapfile -t sources < <(dockerfile_copy_sources "$svc" 2>/dev/null || true)
  if [ "${#sources[@]}" -gt 0 ]; then filter_copy=1; fi
  # Dockerfile & .dockerignore sendiri selalu memengaruhi hasil build.
  sources+=("$dockerfile" ".dockerignore")

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [ "$ctx" = "." ]; then
      rel="$file"
    else
      rel="${file#"$ctx"/}"
    fi
    ignored_by_dockerignore "$ctx_dir" "$rel" && continue
    if [ "$filter_copy" = "1" ] && ! path_in_copy_sources "$rel" "${sources[@]}"; then
      continue
    fi
    list="${list:+$list }$file"
  done < <(
    { git diff --name-only "$base" -- "$ctx" 2>/dev/null || true
      # Perubahan yang belum di-commit (untracked, di luar .gitignore) juga
      # dihitung: image harus mencerminkan isi working tree saat deploy.
      git ls-files --others --exclude-standard -- "$ctx" 2>/dev/null || true
    } | sort -u
  )
  [ -n "$list" ] || return 1
  n="$(printf '%s\n' $list | wc -l)"
  CHANGED_HINT="$(printf '%s\n' $list | head -n 3 | paste -sd ',' - | sed 's/,/, /g')"
  [ "$n" -gt 3 ] && CHANGED_HINT="$CHANGED_HINT (+$((n - 3)) lainnya)"
  return 0
}

# Nilai state setelah service dibangun: kalau working tree masih menyimpan
# perubahan yang ikut ke image, tandai "-dirty" supaya deploy berikutnya tidak
# menganggap image sudah sama dengan commit (aman: akan rebuild sekali lagi).
state_value_for() { # <service>
  local svc="$1"
  if service_changed "$HEAD_SHA" "$HEAD_SHA" "$svc"; then
    printf '%s-dirty' "$HEAD_SHA"
  else
    printf '%s' "$HEAD_SHA"
  fi
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
BE_HINT=""
FE_HINT=""
load_compose_contexts
if [ -z "$COMPOSE_JSON" ]; then
  # Kalau compose tidak bisa dibaca, jangan menebak: build semuanya.
  echo "WARN: 'docker compose config' gagal dibaca — deteksi perubahan dimatikan, semua di-build." >&2
fi

if [ "$DEPLOY_MODE" = "full" ]; then
  BE_NEEDED=1
  FE_NEEDED=1
  BE_HINT="DEPLOY_MODE=full"
  FE_HINT="DEPLOY_MODE=full"
else
  if [ -z "$COMPOSE_JSON" ]; then
    BE_NEEDED=1
    FE_NEEDED=1
    BE_HINT="compose tidak terbaca"
    FE_HINT="compose tidak terbaca"
  else
    if service_changed "$BE_SHA" "$HEAD_SHA" josjob_be; then
      BE_NEEDED=1
      BE_HINT="$CHANGED_HINT"
    else
      BE_NEEDED=0
    fi
    if service_changed "$FE_SHA" "$HEAD_SHA" josjob_fe; then
      FE_NEEDED=1
      FE_HINT="$CHANGED_HINT"
    else
      FE_NEEDED=0
    fi
    if [ "$(state_get FE_ARGS)" != "$(fe_args_fingerprint)" ]; then
      echo "Build args FE berubah (API_BASE_URL/GOOGLE_CLIENT_ID) — frontend di-build ulang."
      FE_NEEDED=1
      FE_HINT="build args berubah"
    fi
  fi
fi

if [ "$FORCE_BE" = "1" ]; then
  BE_NEEDED=1
  BE_HINT="FORCE_BE=1"
fi
if [ "$FORCE_FE" = "1" ]; then
  FE_NEEDED=1
  FE_HINT="FORCE_FE=1"
fi
if [ "$DEPLOY_FE" != "1" ]; then
  FE_NEEDED=0
  FE_HINT="DEPLOY_FE=0"
fi

# Image bisa hilang kalau di-prune manual; kalau begitu wajib build.
if [ "$BE_NEEDED" = "0" ] && ! image_exists "$BE_IMAGE"; then
  echo "Image $BE_IMAGE tidak ada — backend tetap di-build."
  BE_NEEDED=1
  BE_HINT="image belum ada"
fi
if [ "$FE_NEEDED" = "0" ] && ! image_exists "$FE_IMAGE"; then
  echo "Image $FE_IMAGE tidak ada — frontend tetap di-build."
  FE_NEEDED=1
  FE_HINT="image belum ada"
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
if [ -n "$BE_HINT" ]; then
  echo "  backend        : $be_plan  [$BE_HINT]"
else
  echo "  backend        : $be_plan  (terakhir sukses: ${BE_SHA:-belum pernah})"
fi
if [ -n "$FE_HINT" ]; then
  echo "  frontend       : $fe_plan  [$FE_HINT]"
else
  echo "  frontend       : $fe_plan  (terakhir sukses: ${FE_SHA:-belum pernah})"
fi

if [ "$PLAN_ONLY" = "1" ]; then
  echo
  echo "(PLAN_ONLY=1: rencana saja, tidak ada container/image yang disentuh)"
  trap - EXIT ERR TERM INT
  exit 0
fi

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

  state_set BE_SHA "$(state_value_for josjob_be)"
else
  STEP="start backend"
  log "Backend tidak berubah — image $BE_IMAGE dipakai ulang (tanpa rebuild)"
  # Tanpa --build: kalau config/env berubah, compose tetap recreate sendiri.
  "${COMPOSE[@]}" up -d --wait --wait-timeout 120 josjob_be
  # Isi image sudah sama dengan commit ini untuk backend, jadi state bisa maju.
  state_set BE_SHA "$HEAD_SHA"
fi

# --- Frontend ---------------------------------------------------------------
if [ "$FE_NEEDED" = "1" ]; then
  STEP="build frontend"
  log "Build frontend"
  "${COMPOSE[@]}" build josjob_fe

  STEP="start frontend"
  log "Recreate frontend"
  "${COMPOSE[@]}" up -d --force-recreate --wait --wait-timeout 180 josjob_fe

  state_set FE_SHA "$(state_value_for josjob_fe)"
  state_set FE_ARGS "$(fe_args_fingerprint)"
elif [ "$DEPLOY_FE" = "1" ]; then
  STEP="start frontend"
  log "Frontend tidak berubah — image $FE_IMAGE dipakai ulang (tanpa rebuild)"
  "${COMPOSE[@]}" up -d --wait --wait-timeout 120 josjob_fe
  state_set FE_SHA "$HEAD_SHA"
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
