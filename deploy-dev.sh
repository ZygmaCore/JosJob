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
# Opsi bisa lewat FLAG CLI atau environment variable (flag menimpa env var,
# jadi cron/systemd yang sudah menyetel env tidak perlu diubah):
#
#   ./deploy-dev.sh --help
#   ./deploy-dev.sh                    # auto: hanya yang berubah
#   ./deploy-dev.sh --full             # paksa backend + frontend
#   ./deploy-dev.sh --plan             # cuma tampilkan rencana (tidak build/restart)
#   ./deploy-dev.sh --be               # backend saja
#   ./deploy-dev.sh --fe               # frontend saja
#   ./deploy-dev.sh --force-be         # paksa build backend
#   ./deploy-dev.sh --force-fe         # paksa build frontend
#   ./deploy-dev.sh --skip-pull --branch=main
#   ./deploy-dev.sh --seed-demo        # seed demo 1000 baris via mix di Docker
#   ./deploy-dev.sh --seed-live-test   # seed 5 akun role@dev.test via mix di Docker
#   ./deploy-dev.sh --seed-all         # kedua seed di atas
#   ./deploy-dev.sh --seed-only --seed-demo   # hanya seed, tanpa deploy
#
# Padanan env var:
#   DEPLOY_MODE=auto|full  # auto (default) = hanya yang berubah, full = paksa semua
#   PLAN_ONLY=1            # = --plan
#   DEPLOY_BE=0            # = --fe     (backend tidak disentuh)
#   DEPLOY_FE=0            # = --be     (frontend tidak disentuh)
#   FORCE_BE=1 / FORCE_FE=1
#   SKIP_PULL=1 / SKIP_SEED=1
#   SEED_DEMO=1 / SEED_LIVE_TEST=1 / SEED_ONLY=1
#   MIX_IMAGE=hexpm/elixir:1.19.5-erlang-27.3.4.14-ubuntu-noble-20260610
#   BRANCH=main
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
SEED_DEMO="${SEED_DEMO:-0}"
SEED_LIVE_TEST="${SEED_LIVE_TEST:-0}"
SEED_ONLY="${SEED_ONLY:-0}"
MIX_IMAGE="${MIX_IMAGE:-hexpm/elixir:1.19.5-erlang-27.3.4.14-ubuntu-noble-20260610}"
MIX_RUNNER_IMAGE="${MIX_RUNNER_IMAGE:-josjob-mix-runner:local}"
DEPLOY_BE="${DEPLOY_BE:-1}"
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

usage() {
  cat <<'EOF'
Pemakaian: ./deploy-dev.sh [flag...]

  (tanpa flag)        deploy modular: hanya komponen yang berubah sejak sukses terakhir
  --plan, --dry-run   tampilkan rencana build saja (tidak build/restart apa pun)
  --auto              paksa mode auto (kebalikan --full)
  --full              paksa build backend + frontend
  --be                backend saja (frontend tidak disentuh)
  --fe                frontend saja (backend tidak disentuh)
  --force-be          paksa build backend walau tidak ada perubahan
  --force-fe          paksa build frontend walau tidak ada perubahan
  --skip-pull         jangan git pull (pakai isi repo apa adanya)
  --skip-seed         lewati seed database
  --seed-demo         jalankan seed demo (1000 baris) via mix di Docker
  --seed-live-test    jalankan seed 5 akun role@dev.test via mix di Docker
  --seed-all          jalankan kedua seed di atas
  --seed-only         hanya jalankan seed yang diminta, tanpa deploy
  --mix-image=<img>   image builder mix (default: hexpm/elixir:1.19.5-erlang-27.3.4.14-ubuntu-noble-20260610)
  --branch=<nama>     branch yang di-deploy (default: dev)
  -h, --help          tampilkan bantuan ini

Flag menimpa environment variable yang setara (DEPLOY_MODE, PLAN_ONLY,
DEPLOY_BE, DEPLOY_FE, FORCE_BE, FORCE_FE, SKIP_PULL, SKIP_SEED, BRANCH,
SEED_DEMO, SEED_LIVE_TEST, SEED_ONLY, MIX_IMAGE).
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --plan | --dry-run) PLAN_ONLY=1 ;;
    --auto) DEPLOY_MODE=auto ;;
    --full) DEPLOY_MODE=full ;;
    --be | --backend-only) DEPLOY_FE=0 ;;
    --fe | --frontend-only) DEPLOY_BE=0 ;;
    --force-be) FORCE_BE=1 ;;
    --force-fe) FORCE_FE=1 ;;
    --skip-pull) SKIP_PULL=1 ;;
    --skip-seed) SKIP_SEED=1 ;;
    --seed-demo) SEED_DEMO=1 ;;
    --seed-live-test) SEED_LIVE_TEST=1 ;;
    --seed-all) SEED_DEMO=1; SEED_LIVE_TEST=1 ;;
    --seed-only) SEED_ONLY=1 ;;
    --mix-image=*) MIX_IMAGE="${1#*=}" ;;
    --mix-image)
      shift
      [ "$#" -gt 0 ] || {
        echo "--mix-image butuh nilai, mis. --mix-image=hexpm/elixir:1.19.5-erlang-27.3.4.14-ubuntu-noble-20260610" >&2
        exit 2
      }
      MIX_IMAGE="$1"
      ;;
    --branch=*) BRANCH="${1#*=}" ;;
    --branch)
      shift
      [ "$#" -gt 0 ] || {
        echo "--branch butuh nilai, mis. --branch=dev" >&2
        exit 2
      }
      BRANCH="$1"
      ;;
    *)
      echo "Flag tidak dikenal: $1" >&2
      echo >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# --seed-only tanpa seed apa pun = tidak ada kerjaan.
if [ "$SEED_ONLY" = "1" ] && [ "$SEED_DEMO" != "1" ] && [ "$SEED_LIVE_TEST" != "1" ]; then
  echo "--seed-only butuh --seed-demo dan/atau --seed-live-test" >&2
  exit 2
fi
# --seed-only: lewati build/deploy backend & frontend, hanya seed.
if [ "$SEED_ONLY" = "1" ]; then
  DEPLOY_BE=0
  DEPLOY_FE=0
fi

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

# Nama network compose ter-resolve (tahan rename project / COMPOSE_PROJECT_NAME),
# diambil dari `docker compose config` yang sama dengan deploy. Tanpa network
# kustom di compose file, ini network default proyek (<project>_default).
# Dipakai seed saat host DB adalah service compose `paradedb`.
compose_network_name() {
  local name
  [ -n "$COMPOSE_JSON" ] || load_compose_contexts
  name="$(printf '%s' "$COMPOSE_JSON" | jq -r '.networks.default.name // empty' 2>/dev/null || true)"
  if [ -z "$name" ]; then
    echo "Tidak bisa menentukan network compose (docker compose config gagal) — seed ke paradedb dibatalkan." >&2
    return 1
  fi
  printf '%s' "$name"
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

# Host DB efektif untuk seed, mengikuti precedence runtime.exs: DATABASE_URL
# (kalau di-set) menang atas POSTGRES_*; kalau tidak, POSTGRES_HOST (default
# localhost kalau unset). Nilai dibaca dari envs/.env — file yang sama dengan
# yang di-pass ke container seed via --env-file. Spasi di sekitar nilai
# dibuang supaya perbandingan host tidak gagal karena whitespace.
db_effective_host() {
  local url host
  url="$(env_file_value DATABASE_URL)"
  if [ -n "$url" ]; then
    # postgres://user:pass@host:port/db — ambil host di antara @ dan : atau /.
    host="$(printf '%s' "$url" | sed -E 's|^[^:]+://([^@]*@)?([^:/?#]+).*|\2|')"
    host="$(printf '%s' "$host" | tr -d '[:space:]')"
    [ -n "$host" ] && { printf '%s' "$host"; return 0; }
    # URL tidak bisa diparse: jatuh ke POSTGRES_HOST di bawah.
  fi
  host="$(env_file_value POSTGRES_HOST)"
  printf '%s' "${host:-localhost}" | tr -d '[:space:]'
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

# --- Mix via Docker (seed demo / live-test) ---------------------------------
# Container josjob_be tidak berisi mix (runner minimal) dan elixir apt terlalu
# tua — seed demo & live-test dijalankan lewat container sekali pakai dari
# image builder yang sama dengan CI (hexpm/elixir 1.19.5). Repo di-mount,
# envs/.env dipakai sebagai env container. Dijalankan sebagai user saat ini
# (bukan root) supaya _build/deps di repo tetap milik user.
# CATATAN: `mix run` di MIX_ENV=dev tidak menyalakan endpoint Phoenix
# (server hanya nyala kalau PHX_SERVER di-set), jadi tidak bentrok dengan
# backend yang sedang jalan di port 4000.
#
# Jaringan DB: container seed harus mencapai Postgres dengan cara yang sama
# seperti backend. Kalau host DB efektif adalah `paradedb` (nama service
# compose), hostname itu hanya resolve di dalam network compose — container
# dengan --network host akan gagal :nxdomain, persis seperti yang dialami
# backend saat paradedb down. Karena itu, kalau host efektif `paradedb`,
# seed jalan di network compose (nama ter-resolve dari `docker compose
# config`, jadi tahan rename project) dan POSTGRES_PORT dipaksa 5432 — port
# container, yang selalu 5432 sesuai `ports: "${POSTGRES_PORT:-5438}:5432"`
# di compose (5438 hanya port publikasi di host). Kalau host berupa
# IP/hostname lain (mis. Tailscale 100.115.74.9) atau localhost/unset, seed
# tetap di --network host seperti sebelumnya (host mencapai published port;
# POSTGRES_PORT dari env adalah published port). Host efektif diambil dari
# DATABASE_URL kalau di-set (runtime.exs: URL menang atas POSTGRES_*),
# kalau tidak dari POSTGRES_HOST (default localhost).
#
# CA bundle: image hexpm/elixir mentah TIDAK membawa bundle CA OS, dan
# Erlang/OTP (pubkey_os_cacerts) hanya membaca 5 path distro standar —
# /etc/ssl/certs/ca-certificates.crt yang pertama untuk Ubuntu — serta
# TIDAK menghormati SSL_CERT_FILE. Tanpa bundle itu, `mix local.hex`
# crash dengan `:no_cacerts_found` (OTP 27.3.4 tidak punya clause untuk
# atom itu di conv_error_reason/1). Runner di bawah sudah memasang
# ca-certificates, tapi bundle host tetap di-mount read-only ke path
# standar yang sama (kalau host punya) supaya container memakai CA yang
# sama dengan host; kalau host tidak punya, mount dilewati.
# SSL_CERT_FILE di-set ke path yang sama untuk tool berbasis curl/git
# (mis. fetch git dep saat `mix deps.get`); OTP sendiri mengabaikannya.
#
# Git: image hexpm/elixir mentah juga TIDAK membawa git. Mix tetap butuh
# binary git walau dep sudah ada di deps/ — `Mix.Dep.check_lock/1` memanggil
# `git --git-dir=.git config remote.origin.url` untuk tiap dep SCM git
# (mis. heroicons dari GitHub), dan tanpa git hasilnya `ErlangError :enoent`.
# Toolchain C juga tidak ada, padahal bcrypt_elixir / picosat_elixir /
# lazy_html (lexbor) dikompilasi dari source (butuh make, gcc/g++, cmake).
# Karena itu runner adalah image turunan kecil (MIX_RUNNER_IMAGE) berisi
# MIX_IMAGE + paket di MIX_RUNNER_RECIPE, di-cache dan hanya di-build ulang
# kalau image dasar atau daftar paketnya berubah (label josjob.mix.base /
# josjob.mix.recipe). Ini sekali ~1 menit; seed berikutnya tidak install apa-apa.
MIX_RUNNER_RECIPE="git ca-certificates build-essential cmake pkg-config"

ensure_mix_runner_image() {
  local base_id label_base label_recipe
  base_id="$("${DOCKER[@]}" image inspect -f '{{.Id}}' "$MIX_IMAGE" 2>/dev/null || true)"
  if [ -z "$base_id" ]; then
    log "Pull image builder mix ($MIX_IMAGE)"
    "${DOCKER[@]}" pull "$MIX_IMAGE"
    base_id="$("${DOCKER[@]}" image inspect -f '{{.Id}}' "$MIX_IMAGE")"
  fi
  label_base="$("${DOCKER[@]}" image inspect -f '{{index .Config.Labels "josjob.mix.base"}}' "$MIX_RUNNER_IMAGE" 2>/dev/null || true)"
  label_recipe="$("${DOCKER[@]}" image inspect -f '{{index .Config.Labels "josjob.mix.recipe"}}' "$MIX_RUNNER_IMAGE" 2>/dev/null || true)"
  if [ "$label_base" = "$base_id" ] && [ "$label_recipe" = "$MIX_RUNNER_RECIPE" ]; then
    return 0
  fi
  log "Siapkan image runner mix ($MIX_RUNNER_IMAGE): $MIX_RUNNER_RECIPE di atas $MIX_IMAGE"
  "${DOCKER[@]}" build -t "$MIX_RUNNER_IMAGE" \
    --label "josjob.mix.base=$base_id" \
    --label "josjob.mix.recipe=$MIX_RUNNER_RECIPE" - <<EOF
FROM $MIX_IMAGE
RUN apt-get update \\
 && apt-get install -y --no-install-recommends $MIX_RUNNER_RECIPE \\
 && rm -rf /var/lib/apt/lists/*
EOF
}

mix_docker() { # <script .exs relatif repo>
  local script="$1"
  local db_host net_args=() ca_args=()

  db_host="$(db_effective_host)"
  if [ "${db_host,,}" = "paradedb" ]; then
    local net_name
    net_name="$(compose_network_name)" || exit 2
    net_args=(--network "$net_name" -e POSTGRES_PORT=5432)
    log "Seed via network compose ($net_name): POSTGRES_HOST=paradedb, port dipaksa 5432"
  else
    net_args=(--network host)
  fi

  if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
    ca_args=(
      -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
      -e SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    )
  fi

  ensure_mix_runner_image

  "${DOCKER[@]}" run --rm \
    -v "$REPO_DIR:/app" -w /app \
    --env-file "$REPO_DIR/$ENV_FILE" \
    "${net_args[@]}" \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    "${ca_args[@]}" \
    "$MIX_RUNNER_IMAGE" \
    bash -c "(mix hex.info >/dev/null 2>&1 || mix local.hex --force) && (ls \"\$HOME\"/.mix/elixir/*/rebar3 >/dev/null 2>&1 || mix local.rebar --force) && mix deps.get && mix run $script"
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

# Validasi awal: file seed harus ada di branch yang di-deploy. Demo seed
# ada di dev; seed akun live-test hanya ada di RAG-implementation.
if [ "$SEED_DEMO" = "1" ] && [ ! -f apps/josjob/priv/repo/demo_seeds.exs ]; then
  echo "Seed demo tidak ada di branch $BRANCH: apps/josjob/priv/repo/demo_seeds.exs" >&2
  exit 1
fi
if [ "$SEED_LIVE_TEST" = "1" ] && [ ! -f apps/josjob/priv/repo/live_test_accounts.exs ]; then
  echo "Seed live-test tidak ada di branch $BRANCH: apps/josjob/priv/repo/live_test_accounts.exs" >&2
  echo "File ini hanya ada di branch RAG-implementation — jalankan dengan --branch=RAG-implementation" >&2
  exit 1
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
if [ "$DEPLOY_BE" != "1" ]; then
  BE_NEEDED=0
  BE_HINT="DEPLOY_BE=0"
fi
if [ "$DEPLOY_FE" != "1" ]; then
  FE_NEEDED=0
  FE_HINT="DEPLOY_FE=0"
fi

# Image bisa hilang kalau di-prune manual; kalau begitu wajib build.
if [ "$BE_NEEDED" = "0" ] && [ "$DEPLOY_BE" = "1" ] && ! image_exists "$BE_IMAGE"; then
  echo "Image $BE_IMAGE tidak ada — backend tetap di-build."
  BE_NEEDED=1
  BE_HINT="image belum ada"
fi
if [ "$FE_NEEDED" = "0" ] && [ "$DEPLOY_FE" = "1" ] && ! image_exists "$FE_IMAGE"; then
  echo "Image $FE_IMAGE tidak ada — frontend tetap di-build."
  FE_NEEDED=1
  FE_HINT="image belum ada"
fi

if [ "$DEPLOY_BE" != "1" ]; then
  be_plan="skip (DEPLOY_BE=0)"
elif [ "$BE_NEEDED" = "1" ]; then
  be_plan="build"
else
  be_plan="reuse ($BE_IMAGE)"
fi
if [ "$DEPLOY_FE" != "1" ]; then
  fe_plan="skip (DEPLOY_FE=0)"
elif [ "$FE_NEEDED" = "1" ]; then
  fe_plan="build"
else
  fe_plan="reuse ($FE_IMAGE)"
fi
PLAN="backend: $be_plan · frontend: $fe_plan"
if [ "$SEED_DEMO" = "1" ] || [ "$SEED_LIVE_TEST" = "1" ]; then
  seed_plan=""
  [ "$SEED_DEMO" = "1" ] && seed_plan="demo"
  [ "$SEED_LIVE_TEST" = "1" ] && seed_plan="${seed_plan:+$seed_plan+}live-test"
  PLAN="$PLAN · seeds: $seed_plan (via mix di Docker)"
fi

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
# Hanya backend yang butuh DB; kalau backend dilewati (--fe), jangan sentuh.
if [ "$DEPLOY_BE" = "1" ]; then
  STEP="start database"
  log "Start database (paradedb)"
  "${COMPOSE[@]}" up -d --wait paradedb
fi

# --- Backend ----------------------------------------------------------------
if [ "$DEPLOY_BE" != "1" ]; then
  log "Backend dilewati (DEPLOY_BE=0) — container & state backend tidak disentuh"
elif [ "$BE_NEEDED" = "1" ]; then
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

# --- Seed via mix di Docker (demo / live-test) ------------------------------
# Seed ini TIDAK PERNAH otomatis: tidak masuk Release.seed dan tidak ada di
# entrypoint. Dijalankan hanya kalau flag --seed-demo / --seed-live-test
# (atau --seed-all) diminta. Demo seed menulis 1000 baris sintetis — jangan
# dijalankan ke DB yang sedang dipakai live testing organik tanpa persetujuan
# tim; seed live-test idempotent (tidak me-reset password kalau diulang).
if [ "$SEED_DEMO" = "1" ] || [ "$SEED_LIVE_TEST" = "1" ]; then
  STEP="start database"
  log "Start database (paradedb) untuk seed"
  "${COMPOSE[@]}" up -d --wait paradedb

  if [ "$SEED_DEMO" = "1" ]; then
    STEP="seed-demo"
    log "Seed demo (1000 baris) via mix di Docker"
    mix_docker apps/josjob/priv/repo/demo_seeds.exs
  fi

  if [ "$SEED_LIVE_TEST" = "1" ]; then
    STEP="seed-live-test"
    log "Seed akun live-test (5 akun role@dev.test) via mix di Docker"
    mix_docker apps/josjob/priv/repo/live_test_accounts.exs
  fi
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
if [ "$DEPLOY_BE" = "1" ]; then
  log "Verify public API (api-dev.mzkrl.my.id)"
  wait_http https://api-dev.mzkrl.my.id/ 30
fi

if [ "$DEPLOY_FE" = "1" ]; then
  STEP="health check public frontend"
  log "Verify public frontend (dev.mzkrl.my.id)"
  wait_http https://dev.mzkrl.my.id/ 30
fi

STEP="done"
if [ "$DEPLOY_BE" = "1" ] && [ "$DEPLOY_FE" = "1" ] &&
  [ "$BE_NEEDED" = "0" ] && [ "$FE_NEEDED" = "0" ] && [ "$DEPLOY_MODE" = "auto" ]; then
  NO_CHANGES=1
  log "Deploy OK — tidak ada perubahan kode sejak deploy terakhir, semua service tetap jalan"
else
  log "Deploy OK"
fi
