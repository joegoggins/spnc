FROM nginx:1.27-alpine
# Links this GHCR package to the repo (so Actions' GITHUB_TOKEN can push to it).
LABEL org.opencontainers.image.source="https://github.com/joegoggins/spnc"
COPY index.html style.css favicon.svg background.svg /usr/share/nginx/html/
EXPOSE 80
# nginx:alpine's default CMD already runs `nginx -g 'daemon off;'`.
