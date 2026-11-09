# syntax=docker/dockerfile:1

# =============================================================================
# Backend (Elixir umbrella) — local dev / preview image.
#
# Runs the Phoenix JSON API (app :stellar_web, all umbrella apps) as an OTP
# release. Built as a PROD release on purpose: config/runtime.exs binds the
# endpoint on all interfaces in prod, whereas dev mode binds 127.0.0.1 (which is
# unreachable from outside the container) and spawns asset watchers. The release
# also ships the migrate/seed helpers (rel/overlays/bin/*).
#
# WHY THIS IMAGE EXISTS: the `xberg` Rust NIF publishes no precompiled binary for
# Windows-MSVC (only linux-gnu / windows-gnu / apple-darwin), and
# config/config.exs sets `force_build: xberg: true`, so it is compiled from
# source — hence the Rust toolchain below. Building in a Linux/glibc container
# sidesteps the broken Windows-native toolchain entirely.
#
# Base images MUST be glibc (debian), NOT musl/alpine: the NIF's precompiled
# target list has x86_64-unknown-linux-gnu but no -musl, and the C NIFs link
# glibc too. Versions pinned to .tool-versions (elixir 1.19.5 / erlang 27.3.4.3).
#
#   docker compose --env-file envs/.env up -d --build stellar_be   ->  :4000
# =============================================================================

ARG ELIXIR_IMAGE=hexpm/elixir:1.19.5-erlang-27.3.4.3-debian-bookworm-20260610-slim
# Runtime base is debian sid (unstable) ON PURPOSE: the xberg NIF's only external
# dynamic dependency is libheif, and it needs a symbol (heif_image_get_plane2)
# that only exists in libheif >= ~1.20 — stable/testing (bookworm 1.15, trixie
# 1.19.8) are too old; sid ships 1.23. The release is built on bookworm and runs
# here fine (glibc is forward-compatible: newer glibc runs older-linked binaries).
ARG RUNNER_IMAGE=debian:sid-slim

# ---- Build stage ------------------------------------------------------------
FROM ${ELIXIR_IMAGE} AS build

# git             : git-sourced deps (heroicons)
# build-essential : C NIFs (bcrypt_elixir, picosat_elixir) via elixir_make/cc
# curl + ca-certs : rustup installer over https
RUN apt-get update -y \
 && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Rust toolchain — xberg's rustler NIF is force-built from source (config.exs).
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --profile minimal --default-toolchain stable

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Dependencies first, so the (slow) fetch+compile layer is cached until the
# lockfile or any app's mix.exs changes. The umbrella needs every child app's
# mix.exs to resolve deps, so the apps tree is copied here.
COPY mix.exs mix.lock ./
COPY config config
COPY apps apps
# hex.pm tarball fetches time out on a slow/flaky link, and the default 8
# parallel connections make it worse (a single timed-out tarball with no cached
# copy fails the whole build). Serialize the fetch + raise the timeout (hex's
# own advice on repeated ":timeout"), and retry once — the retry reuses tarballs
# the first attempt already cached, so one flaky download no longer fails here.
ENV HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120
RUN mix deps.get --only prod || mix deps.get --only prod
RUN mix deps.compile

# Compile the umbrella and assemble the release. Static web assets are NOT built
# here — this image serves the JSON API; the admin/LiveDashboard HTML assets are
# undigested (Phoenix serves them undigested + logs a warning, no crash).
COPY rel rel
# Normalize CRLF -> LF on the release helper scripts in case the build context
# came from a Windows checkout (a stray \r breaks their /bin/sh shebang).
RUN sed -i 's/\r$//' rel/overlays/bin/* 2>/dev/null || true
RUN mix compile
RUN mix release stellar

# ---- Runtime stage ----------------------------------------------------------
FROM ${RUNNER_IMAGE} AS runtime

# libstdc++6/openssl/libncurses6 : Erlang VM + NIF runtime deps; locales : UTF-8.
# libheif1 : the xberg NIF is dynamically linked against libheif.so.1 (HEIF/HEIC
#            image support) — without it the NIF fails to load and the VM crashes
#            on boot. apt pulls libheif1's codec deps (libde265, …) automatically.
RUN apt-get update -y \
 && apt-get install -y --no-install-recommends \
      libstdc++6 openssl libncurses6 locales ca-certificates libheif1 \
 && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 MIX_ENV=prod
WORKDIR /app

COPY --from=build /app/_build/prod/rel/stellar ./

# config/runtime.exs (Dotenvy) reads $RELEASE_ROOT/.env and .prod.overrides.env.
# Create empty files so a missing file can never trip the loader — real values
# arrive via OS env (docker compose environment/env_file), which Dotenvy lets win.
RUN touch .env .prod.overrides.env

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Strip any CRLF (Windows checkout) then make it executable.
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 4000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bin/server"]
