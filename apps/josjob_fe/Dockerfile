# syntax=docker/dockerfile:1

# ---- Build stage: compile the Flutter web bundle ----------------------------
# Pinned to the newest cirruslabs tag in the 3.44 line (bundles Dart 3.12.0; the
# app targets Dart >=3.12.0). cirruslabs publishes no 3.44.1-3.44.4 image, and
# `stable` is a moving target, so pinning 3.44.0 keeps builds reproducible.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /app

# Copy manifests first so `pub get` is cached until dependencies change.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the sources and build the release web bundle.
COPY . .

# API_BASE_URL / GOOGLE_CLIENT_ID are compile-time constants baked into the web
# bundle by Dart's String.fromEnvironment (see lib/services/api_config.dart), so
# they MUST be injected here with --dart-define. Without this the release
# hard-codes the localhost defaults and the deployed app calls the visitor's own
# machine. CI passes real values via --build-arg (from CI/CD variables);
# the defaults below keep local `docker compose up --build` working.
ARG API_BASE_URL=http://localhost:4000
ARG GOOGLE_CLIENT_ID=
# --pwa-strategy=none disables the PWA service worker. For a dev/preview image
# the offline service worker only causes stale-build confusion (it keeps serving
# cached JS after a rebuild); without it a plain browser refresh always loads the
# latest bundle.
RUN flutter build web --release \
      --pwa-strategy=none \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"

# ---- Runtime stage: serve the static bundle with nginx ----------------------
# Unprivileged nginx runs as a non-root user and listens on 8080 by default.
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=6 \
  CMD wget -qO- http://127.0.0.1:8080/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
