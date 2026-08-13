#!/bin/sh
# Generates /usr/share/nginx/html/env.js from the APP_API_URL environment
# variable at container startup. Executed automatically by the official
# nginx image entrypoint (any *.sh under /docker-entrypoint.d) before nginx
# starts, so a single image can serve any environment.
#
# Falls back to the build-time VITE_API_URL (carried into the runtime stage
# as an env var) for backwards compatibility, then to empty — in which case
# the app uses window.location.origin.
set -e

: "${APP_API_URL:=${VITE_API_URL:-}}"

printf 'window.__APP_CONFIG__ = { apiUrl: "%s" };\n' "$APP_API_URL" \
  > /usr/share/nginx/html/env.js
