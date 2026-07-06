# ============================================================
# Presentation Tier Dockerfile - Nginx + static HTML/CSS/JS
# ============================================================
FROM nginx:1.27-alpine

LABEL tier="presentation" \
      app="lms-platform"

# Pull in the latest patched Alpine packages at build time (e.g. OpenSSL
# security fixes) rather than depending on how recently nginx:1.27-alpine
# itself was republished upstream.
RUN apk update && apk upgrade --no-cache

# Remove default nginx config and site content
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Copy our custom server config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static site files
COPY index.html login.html register.html course.html dashboard.html /usr/share/nginx/html/
COPY css /usr/share/nginx/html/css
COPY js /usr/share/nginx/html/js

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/nginx-health || exit 1

CMD ["nginx", "-g", "daemon off;"]
