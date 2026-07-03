# ---- build stage: compile the Vite app to static assets ----
# Pin to the native build platform so multi-arch (amd64+arm64) builds don't run
# the Node/npm build under QEMU emulation — dist/ is arch-independent static files.
FROM --platform=$BUILDPLATFORM node:22-alpine AS build
WORKDIR /app
# Install deps first (cached unless package*.json changes).
COPY package.json package-lock.json ./
RUN npm ci
# Then the source, and build -> /app/dist.
COPY . .
RUN npm run build

# ---- serve stage: static files behind nginx (per target arch) ----
FROM nginx:1.27-alpine AS serve
# Links this GHCR package to the repo (so Actions' GITHUB_TOKEN can push to it).
LABEL org.opencontainers.image.source="https://github.com/joegoggins/spnc"
# The /api reverse-proxy config is a template: nginx:alpine's entrypoint sources
# *.envsh files (which set NGINX_RESOLVER + APP_API_UPSTREAM) and then runs
# envsubst on /etc/nginx/templates/*.template at startup. NGINX_ENVSUBST_FILTER
# restricts substitution to those two vars so nginx's own $variables survive.
# APP_API_UPSTREAM here is the default; the helm chart overrides it per-namespace.
ENV NGINX_ENVSUBST_FILTER='^(APP_API_UPSTREAM|NGINX_RESOLVER)$' \
    APP_API_UPSTREAM=app-api.sp-staging.svc.cluster.local:80
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --chmod=0755 docker-entrypoint.d/10-collabornet-api-upstream.envsh /docker-entrypoint.d/10-collabornet-api-upstream.envsh
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
# nginx:alpine's default CMD already runs `nginx -g 'daemon off;'`.
