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
# Semua input lewat environment variable, semuanya opsional:
#   STATUS     SUCCESS | FAILED | SKIPPED        (default: INFO)
#   STEP       step yang sedang berjalan / gagal
#   EXIT_CODE  exit code deploy
#   DURATION   durasi human-readable, mis. "12m 34s"
#   BRANCH     branch git
#   COMMIT     "7654eb0 fix(fe): ..." (short hash + subjek)
#   TRIGGER    manual | cron
#   DETAIL     teks tambahan (mis. tail log saat gagal)
#   REPO_DIR   lokasi repo (default: /home/mzkrl/JosJob)
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
  '[
    {name: "Branch",   value: $branch,   inline: true},
    {name: "Commit",   value: $commit,   inline: false},
    {name: "Trigger",  value: $trigger,  inline: true},
    {name: "Step",     value: $step,     inline: true},
    {name: "Duration", value: $duration, inline: true},
    {name: "Exit code", value: $code,    inline: true}
  ]')"

payload="$(jq -n \
  --arg title "$title" \
  --arg summary "$summary" \
  --argjson color "$color" \
  --argjson fields "$fields" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg footer "JosJob dev VPS · $(hostname) · https://dev.mzkrl.my.id" \
  --arg detail "$detail_block" \
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
   }')"

echo "notify: mengirim status $STATUS ke Discord..."

# --- Kirim dengan retry (network / rate limit sementara) --------------------
attempt=1
while [ "$attempt" -le 3 ]; do
  if response="$(curl --silent --show-error --fail-with-body \
        --max-time 20 \
        -H 'Content-Type: application/json' \
        -H "User-Agent: JosJob-Deploy/1.0 (+$REPO_DIR)" \
        -X POST -d "$payload" "$DISCORD_WEBHOOK_URL" 2>&1)"; then
    echo "notify: terkirim"
    exit 0
  fi
  echo "notify: percobaan $attempt gagal: ${response:0:300}" >&2
  attempt=$((attempt + 1))
  [ "$attempt" -le 3 ] && sleep 5
done

echo "notify: gagal mengirim notifikasi setelah 3 percobaan" >&2
exit 0
