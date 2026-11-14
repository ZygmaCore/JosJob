#!/usr/bin/env bash
# =============================================================================
# Kirim notifikasi hasil deploy ke Discord webhook.
#
# Dipakai otomatis oleh deploy-dev.sh (manual maupun cron) lewat EXIT trap,
# dan oleh deploy-cron.sh untuk kasus script mati sebelum sempat melapor.
#
# Konfigurasi webhook (tidak masuk repo):
#   envs/deploy.env  ->  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
#
# Input lewat environment variable (semua opsional):
#   STATUS       SUCCESS | FAILED | SKIPPED          (default: INFO)
#   STEP         step yang sedang berjalan / gagal
#   EXIT_CODE    exit code deploy
#   DURATION     durasi human-readable, mis. "12m 34s"
#   BRANCH       branch git
#   COMMIT       "7654eb0 fix(fe): ..." (short hash + subjek)
#   TRIGGER      manual | cron
#   DETAIL       teks tambahan (mis. tail log saat gagal)
#   RUN_ID       id run; dipakai untuk nama file log
#   ATTACH_LOG   path file log yang dikirim sebagai attachment (full log)
#   ATTACH_NAME  nama file attachment (default: deploy-<RUN_ID>.log)
#   REPO_DIR     lokasi repo (default: /home/mzkrl/JosJob)
#
# Log dikirim utuh sebagai attachment. Kalau lebih dari ~7,5 MB (batas upload
# webhook Discord 8 MiB), dikirim versi .gz; kalau masih kebesaran, tail-nya.
# Jadi log tetap tersimpan di Discord walaupun file di server sudah dirotasi
# atau terhapus pada run berikutnya.
#
# Script ini tidak pernah mengembalikan exit != 0: notifikasi yang gagal
# tidak boleh menggagalkan (atau mengubah status) deploy.
# =============================================================================
set -uo pipefail

REPO_DIR="${REPO_DIR:-/home/mzkrl/JosJob}"

# Webhook dibaca dari envs/deploy.env kalau belum ada di environment.
if [ -z "${DISCORD_WEBHOOK_URL:-}" ] && [ -f "$REPO_DIR/envs/deploy.env" ]; then
  # shellcheck disable=SC1091
  set -a
  . "$REPO_DIR/envs/deploy.env"
  set +a
fi

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
  echo "notify: DISCORD_WEBHOOK_URL kosong, notifikasi dilewati" >&2
  exit 0
fi
command -v jq >/dev/null 2>&1 || {
  echo "notify: jq tidak tersedia, notifikasi dilewati" >&2
  exit 0
}

STATUS="${STATUS:-INFO}"
STEP="${STEP:--}"
EXIT_CODE="${EXIT_CODE:-0}"
DURATION="${DURATION:--}"
BRANCH="${BRANCH:--}"
COMMIT="${COMMIT:--}"
TRIGGER="${TRIGGER:--}"
DETAIL="${DETAIL:-}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
ATTACH_LOG="${ATTACH_LOG:-}"
ATTACH_NAME="${ATTACH_NAME:-deploy-${RUN_ID}.log}"
MAX_UPLOAD=7500000 # ~7,5 MB, di bawah batas 8 MiB webhook Discord

tmp_gz=""
tmp_tail=""
cleanup() {
  [ -n "$tmp_gz" ] && rm -f "$tmp_gz"
  [ -n "$tmp_tail" ] && rm -f "$tmp_tail"
  return 0
}
trap cleanup EXIT

human_size() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || printf '%s bytes' "$1"; }

# --- Siapkan attachment -----------------------------------------------------
attach_path=""
attach_name=""
attach_note="tidak dilampirkan"
if [ -n "$ATTACH_LOG" ] && [ -f "$ATTACH_LOG" ]; then
  raw_size="$(stat -c %s "$ATTACH_LOG")"
  if [ "$raw_size" -le "$MAX_UPLOAD" ]; then
    attach_path="$ATTACH_LOG"
    attach_name="$ATTACH_NAME"
  else
    tmp_gz="$(mktemp /tmp/josjob-log.XXXXXX.gz)"
    if gzip -9 -c "$ATTACH_LOG" >"$tmp_gz" 2>/dev/null && [ -s "$tmp_gz" ] &&
      [ "$(stat -c %s "$tmp_gz")" -le "$MAX_UPLOAD" ]; then
      attach_path="$tmp_gz"
      attach_name="$ATTACH_NAME.gz"
    else
      tmp_tail="$(mktemp /tmp/josjob-log.XXXXXX.tail)"
      tail -c 700000 "$ATTACH_LOG" >"$tmp_tail" 2>/dev/null || true
      attach_path="$tmp_tail"
      attach_name="$ATTACH_NAME.tail"
    fi
  fi
  if [ -n "$attach_path" ]; then
    attach_note="\`$attach_name\` ($(human_size "$(stat -c %s "$attach_path")"))"
  fi
fi

# --- Judul, warna, dan ringkasan sesuai status -------------------------------
case "$STATUS" in
  SUCCESS)
    emoji="✅"
    title="Deploy SUCCESS — JosJob dev"
    color=3066993 # hijau
    summary="Backend + frontend berhasil di-deploy dan lolos health check."
    ;;
  FAILED)
    emoji="❌"
    title="Deploy FAILED — JosJob dev"
    color=15158332 # merah
    summary="Deploy berhenti. Cek log di server sebelum menjalankan ulang."
    ;;
  SKIPPED)
    emoji="⏭️"
    title="Deploy SKIPPED — JosJob dev"
    color=15105570 # oranye
    summary="Jadwal cron tiba, tapi deploy sebelumnya masih berjalan."
    ;;
  *)
    emoji="ℹ️"
    title="Deploy INFO — JosJob dev"
    color=3447003 # biru
    summary="Informasi deploy JosJob dev."
    ;;
esac
title="$emoji $title"

# --- Bersihkan & batasi detail (tail log) -----------------------------------
# Docker --progress plain mengeluarkan ANSI, dan backtick bisa memutus code
# block embed, jadi keduanya dibuang.
detail_clean="$(printf '%s' "$DETAIL" | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/\r//g' | tr -d '`')"
if [ "${#detail_clean}" -gt 3200 ]; then
  detail_clean="$(printf '%s' "$detail_clean" | tail -c 3200)"
  detail_clean="… (dipotong, lihat log lengkap di server)
$detail_clean"
fi
detail_block=""
if [ -n "${detail_clean//[[:space:]]/}" ]; then
  detail_block="$(printf '```\n%s\n```' "$detail_clean")"
fi

# --- Susun payload ----------------------------------------------------------
fields="$(jq -n \
  --arg branch "$BRANCH" \
  --arg commit "$COMMIT" \
  --arg trigger "$TRIGGER" \
  --arg step "$STEP" \
  --arg duration "$DURATION" \
  --arg code "$EXIT_CODE" \
  --arg log "$attach_note" \
  '[
    {name: "Branch",   value: $branch,   inline: true},
    {name: "Commit",   value: $commit,   inline: false},
    {name: "Trigger",  value: $trigger,  inline: true},
    {name: "Step",     value: $step,     inline: true},
    {name: "Duration", value: $duration, inline: true},
    {name: "Exit code", value: $code,    inline: true},
    {name: "Log",      value: $log,      inline: false}
  ]')"

payload="$(jq -n \
  --arg title "$title" \
  --arg summary "$summary" \
  --argjson color "$color" \
  --argjson fields "$fields" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg footer "JosJob dev VPS · $(hostname) · https://dev.mzkrl.my.id" \
  --arg detail "$detail_block" \
  --arg attach_name "$attach_name" \
  --argjson has_attach "$([ -n "$attach_name" ] && echo true || echo false)" \
  '{
     username: "JosJob Deploy",
     embeds: (
       [{
         title: $title,
         description: $summary,
         color: $color,
         fields: $fields,
         timestamp: $timestamp,
         footer: {text: $footer}
       }]
       + (if $detail == "" then [] else [{description: $detail, color: $color}] end)
     )
   }
   + (if $has_attach then {attachments: [{id: 0, filename: $attach_name}]} else {} end)')"

if [ -n "$attach_name" ]; then
  echo "notify: mengirim status $STATUS + attachment $attach_name ke Discord..."
else
  echo "notify: mengirim status $STATUS ke Discord..."
fi

# --- Kirim dengan retry (network / rate limit sementara) --------------------
attempt=1
while [ "$attempt" -le 3 ]; do
  if [ -n "$attach_name" ]; then
    response="$(curl --silent --show-error --fail-with-body \
      --max-time 120 \
      -H "User-Agent: JosJob-Deploy/1.0 (+$REPO_DIR)" \
      -F "files[0]=@$attach_path;filename=$attach_name" \
      --form-string "payload_json=$payload" \
      -X POST "$DISCORD_WEBHOOK_URL" 2>&1)"
  else
    response="$(curl --silent --show-error --fail-with-body \
      --max-time 20 \
      -H 'Content-Type: application/json' \
      -H "User-Agent: JosJob-Deploy/1.0 (+$REPO_DIR)" \
      -d "$payload" \
      -X POST "$DISCORD_WEBHOOK_URL" 2>&1)"
  fi
  status=$?
  if [ "$status" -eq 0 ]; then
    echo "notify: terkirim"
    exit 0
  fi
  echo "notify: percobaan $attempt gagal (curl exit $status): ${response:0:300}" >&2
  attempt=$((attempt + 1))
  [ "$attempt" -le 3 ] && sleep 5
done

echo "notify: gagal mengirim notifikasi setelah 3 percobaan" >&2
exit 0
