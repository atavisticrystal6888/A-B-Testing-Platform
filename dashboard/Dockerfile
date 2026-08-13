# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS build

WORKDIR /app

COPY docker/certs/ /usr/local/share/ca-certificates/
RUN apk add --no-cache ca-certificates && update-ca-certificates

ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}

COPY dashboard/package.json dashboard/package-lock.json ./
RUN npm ci

COPY dashboard/ ./

RUN npm run build

FROM nginx:1.27-alpine AS runtime

# Build-time value kept only as a runtime fallback for env.js generation;
# prefer setting APP_API_URL on the container instead.
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}

COPY dashboard/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# Regenerates /usr/share/nginx/html/env.js from APP_API_URL on every start
# (runs via the official image's /docker-entrypoint.d hook before nginx).
COPY dashboard/docker/40-generate-env-config.sh /docker-entrypoint.d/40-generate-env-config.sh
RUN sed -i 's/\r$//' /docker-entrypoint.d/40-generate-env-config.sh \
  && chmod +x /docker-entrypoint.d/40-generate-env-config.sh

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]