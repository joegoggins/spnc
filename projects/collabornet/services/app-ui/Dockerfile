# ---- build stage: compile the Vite app to static assets ----
FROM node:22-alpine AS build
WORKDIR /app
# Install deps first (cached unless package*.json changes).
COPY package.json package-lock.json ./
RUN npm ci
# Then the source, and build -> /app/dist.
COPY . .
RUN npm run build

# ---- serve stage: static files behind nginx ----
FROM nginx:1.27-alpine AS serve
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
# nginx:alpine's default CMD already runs `nginx -g 'daemon off;'`.
