# CloudCampus LMS - 3-tier learning platform

A small learning management system used as the base application for a full
DevOps pipeline: Terraform -> Ansible -> Jenkins CI -> Docker Compose (dev) ->
manual approval -> ArgoCD -> Kubernetes (prod, with RDS) -> Prometheus/Grafana
+ ELK via Helm.

## Architecture

| Tier | Technology | Folder |
|---|---|---|
| Presentation | Nginx + HTML/CSS/Vanilla JS | `frontend/` |
| Application | Node.js + Express | `backend/` |
| Data | PostgreSQL (dev/test container, RDS in prod) | `database/` |

## Features implemented

- User registration/login (JWT-based auth)
- Course catalog and module browsing
- Quiz taking with automatic scoring
- Automatic certificate issuance on course completion
- Enrollment tracking and a personal dashboard
- `/health` endpoint on the backend for container/K8s probes

## Running locally with Docker Compose

```bash
cd lms-app
docker compose up --build
```

- Frontend: http://localhost:8080
- Backend API: http://localhost:5000/api
- Backend health check: http://localhost:5000/health
- Postgres: localhost:5432 (user: lms_user / password: lms_password / db: lms_db)

The frontend's Nginx reverse-proxies `/api/*` and `/health` to the backend
container, so the same static build works unchanged once you move to
Kubernetes - you'll just point that proxy (or an Ingress) at the backend
Service instead.

## Moving to production

- **Data tier**: swap the `database` service for an AWS RDS PostgreSQL
  endpoint. Only `DB_HOST` (and TLS settings) change in the backend's
  environment - no application code changes needed.
- **Backend/Frontend**: the same Docker images built by Jenkins are pushed to
  Docker Hub and deployed via Kubernetes Deployment/Service/ConfigMap/Secret
  manifests, synced by ArgoCD.

## Next steps in the roadmap

1. Push this repo to GitHub.
2. Write Terraform to provision the Jenkins host, EKS cluster, and RDS instance.
3. Write an Ansible playbook to install/configure Jenkins on the provisioned host.
4. Build the Jenkins declarative pipeline (Checkout -> Build -> Test -> SonarQube
   -> Quality Gate -> Trivy FS -> Docker Build -> Trivy Image -> Push -> Deploy Dev
   -> Manual Approval -> ArgoCD sync).
5. Write Kubernetes manifests for production.
6. Install Prometheus/Grafana and Filebeat/ELK via Helm, and configure alerting.

Let me know when you've verified this runs locally and I'll help with the next step.
