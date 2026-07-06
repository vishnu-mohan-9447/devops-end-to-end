# ============================================================
# Data Tier Dockerfile (Dev/Test environment only)
# In Production, this is replaced by AWS RDS - no container needed.
# ============================================================
FROM postgres:16-alpine

LABEL tier="data" \
      app="lms-platform" \
      environment="dev-test"

ENV POSTGRES_DB=lms_db \
    POSTGRES_USER=lms_user \
    POSTGRES_PASSWORD=lms_password

# Any *.sql or *.sh file dropped here is executed once, in order,
# the first time the container starts with an empty data directory.
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
  CMD pg_isready -U lms_user -d lms_db || exit 1
