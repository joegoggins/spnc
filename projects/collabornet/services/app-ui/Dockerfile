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
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
# nginx:alpine's default CMD already runs `nginx -g 'daemon off;'`.
