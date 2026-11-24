# syntax=docker/dockerfile:1
FROM hexpm/elixir:1.19.5-erlang-27.3.4.3-debian-bookworm-20260610-slim AS build
WORKDIR /app
ENV MIX_ENV=prod HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod --check-locked && mix deps.compile
COPY lib lib
RUN mix release

FROM debian:bookworm-slim
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends openssl libstdc++6 libncurses6 ca-certificates qpdf poppler-utils curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 MIX_ENV=prod
COPY --from=build /app/_build/prod/rel/josjob_ragpdf ./
EXPOSE 4010
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=10 \
  CMD curl -fsS http://127.0.0.1:4010/health >/dev/null || exit 1
CMD ["bin/josjob_ragpdf", "start"]
