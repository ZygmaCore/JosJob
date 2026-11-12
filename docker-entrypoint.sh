#!/bin/sh
# Entrypoint for the Josjob backend release (local dev / preview).
#
# Runs DB migrations (fatal on failure) then the idempotent seed (best-effort:
# a hiccup — e.g. a Cloudflare video-seed timeout — must not wedge the API),
# then starts the Phoenix server. Postgres readiness is gated upstream by the
# compose healthcheck (depends_on: paradedb: condition: service_healthy).
set -e

echo "[entrypoint] migrating database..."
bin/migrate

echo "[entrypoint] seeding (idempotent)..."
if ! bin/seed; then
  echo "[entrypoint] WARNING: seed did not complete — continuing without full seed data."
fi

echo "[entrypoint] starting Phoenix server on port ${PORT:-4000}..."
exec "$@"
