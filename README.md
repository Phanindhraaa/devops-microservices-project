# 🚀 DevOps Task Manager – Production Platform

Production-grade full‑stack **Task Manager** application showcasing end‑to‑end DevOps: CI/CD, Docker, Kubernetes, monitoring, and Terraform‑based IaC.

***

## 🏗️ Architecture Overview

```text
Browser
  ↓
Ingress (devops-app.local) / NodePort (30080)
  ↓
Frontend (Nginx, 2 replicas)
  ↓  /api, /health
Backend API (Node.js/Express, 2 replicas, /metrics)
  ↓
MongoDB (1 replica, 1Gi PVC)

Monitoring Namespace:
Prometheus ← backend /metrics, kube-state-metrics, node-exporter
Grafana (dashboards)
```

***

## 🛠️ Tech Stack

| Layer        | Technologies                                                                 |
|-------------|------------------------------------------------------------------------------|
| Frontend    | Nginx (Alpine), static HTML/JS, ConfigMap‑based content, Ingress/NodePort    |
| Backend     | Node.js 18, Express 5, Mongoose 9, CORS, prom‑client (Prometheus metrics)    |
| Database    | MongoDB 7, Kubernetes Deployment + PVC (1Gi), ClusterIP service             |
| CI/CD       | GitHub Actions, Docker Buildx, Docker Hub                                   |
| Orchestration | Kubernetes (Deployments, Services, Ingress, ConfigMaps, PVCs)             |
| Monitoring  | Prometheus, Grafana, kube‑state‑metrics, node‑exporter                      |
| IaC         | Terraform (kreuzwerker/docker provider)                                     |

***

## ⚙️ CI/CD Pipeline (GitHub Actions)

### Workflow Triggers

- On `push` to `main`
- On `pull_request` targeting `main`

### Jobs

1. **build-and-push-backend**
   - Checks out code
   - Builds backend image from `./apps/backend`
   - Tags using:
     - `branch` + `sha`
     - `latest` on default branch
   - Pushes to Docker Hub:  
     `DOCKERHUB_USERNAME/backend-api:…`
   - Uses registry cache (`cache-from` / `cache-to`)

2. **build-and-push-frontend**
   - Checks out code
   - Builds frontend image from `./apps/frontend`
   - Tags and pushes to Docker Hub:  
     `DOCKERHUB_USERNAME/frontend:…`
   - Uses registry cache

3. **deploy**
   - Runs only on `main` branch
   - Depends on both build jobs
   - Placeholder step to update Kubernetes manifests (prints the images that would be deployed):
     - `DOCKERHUB_USERNAME/backend-api:latest`
     - `DOCKERHUB_USERNAME/frontend:latest`

### Required GitHub Secrets

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

***

## 🔧 Backend API (Node.js / Express / MongoDB)

Location: `./apps/backend`

### Dependencies

- `express` – Web framework & routing
- `mongoose` – MongoDB object modeling
- `cors` – Cross‑origin support for frontend
- `prom-client` – Prometheus metrics

### Data Model

```js
Task = {
  title: String,
  completed: Boolean,
  createdAt: Date (default: now)
}
```

### Environment

- `PORT` (default: `5000`)
- `MONGO_URI`  
  Example used in Kubernetes:

```text
mongodb://admin:password123@mongodb-service:27017/devops_db?authSource=admin
```

### API Endpoints

| Method | Path                | Description                          |
|--------|---------------------|--------------------------------------|
| GET    | `/`                 | Basic API status & version          |
| GET    | `/health`           | Health check (API + DB status)      |
| GET    | `/api`              | API info + available endpoints      |
| GET    | `/api/tasks`        | List all tasks                      |
| POST   | `/api/tasks`        | Create a new task                   |
| DELETE | `/api/tasks/:id`    | Delete task by ID                   |
| GET    | `/metrics`          | Prometheus metrics (text format)    |

`/health` returns JSON with backend status and MongoDB connection state (connected/disconnected).

### Prometheus Metrics

Configured via **prom-client**:

- Default process and Node.js metrics with prefix `backend_api_`
- Custom metrics:
  - `http_request_duration_seconds{method,route,status_code}`
  - `http_requests_total{method,route,status_code}`
  - `mongodb_connection_status` (1 = connected, 0 = disconnected)

Middleware records duration and count for every HTTP request.

### Backend Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY server.js ./

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "server.js"]
```

- Lightweight `node:18-alpine`
- Production dependencies only
- `/health`‑based container healthcheck

***

## 🖥️ Frontend (Nginx SPA)

You have two flavors:

1. **Static Docker image** (for general container deploys)
2. **Kubernetes ConfigMap‑driven frontend** (HTML from ConfigMap)

### Standalone Frontend Dockerfile (apps/frontend)

```dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### Frontend UI (public/index.html)

Features:

- Modern Task Manager UI with:
  - Task list
  - Add and delete capabilities
  - Created timestamp display
- Health/status bar:
  - Frontend status
  - Backend status (via `/health`)
  - Database status (via `/health` response)
- Backend version display (from `/`)
- Auto health check every 30 seconds

Frontend uses:

```js
const API_URL = window.location.hostname === 'localhost'
  ? 'http://localhost:5000'
  : '';
```

- Local dev: talks directly to `localhost:5000`
- In cluster: uses relative paths (`/api`, `/health`) that are proxied via Nginx to the backend service.

***

## ☸️ Kubernetes Manifests

Top‑level structure:

```text
kubernetes/
  backend/
    deployment.yaml
    service.yaml
  frontend/
    (ConfigMaps, deployment, service, ingress)
  database/
    deployment.yaml
    pvc + service
```

### Backend (kubernetes/backend)

**Deployment (`backend-api`)**

- 2 replicas (high availability)
- Image: `phanindhrasura/backend-api:latest`
- Exposes container port `5000`
- Env:
  - `MONGO_URI` as above
- Resource requests/limits:
  - Requests: `100m` CPU, `64Mi` memory
  - Limits: `200m` CPU, `128Mi` memory

**Service (`backend-service`)**

- Type: `ClusterIP`
- Port: `80` (service)
- TargetPort: `5000` (container)
- Label selector: `app: backend`

Frontend and Ingress use `backend-service:80` for API and health checks.

### Database (kubernetes/database)

**Deployment (`mongodb`)**

- 1 replica (typical for a simple demo; could be StatefulSet in more advanced cases)
- Image: `mongo:7.0`
- Env:
  - `MONGO_INITDB_ROOT_USERNAME=admin`
  - `MONGO_INITDB_ROOT_PASSWORD=password123`
  - `MONGO_INITDB_DATABASE=devops_db`
- `volumeMounts`:
  - Mounts `mongo-storage` at `/data/db`
- Resource requests/limits:
  - Requests: `100m` CPU, `256Mi` memory
  - Limits: `200m` CPU, `512Mi` memory

**PersistentVolumeClaim (`mongo-pvc`)**

- `storageClassName: standard`
- `accessModes: ReadWriteOnce`
- Requests: `1Gi`

**Service (`mongodb-service`)**

- Type: `ClusterIP`
- Port: `27017`
- TargetPort: `27017`
- Selector: `app: database`

Backend connects via `mongodb-service:27017`.

### Frontend on Kubernetes (kubernetes/frontend)

#### ConfigMap: `frontend-html`

- Embeds a simple demo HTML page (`index.html`) showing:
  - High‑level description of the DevOps Microservices project
  - Service status badges
  - Buttons to call the backend API (`/api/`) and show health

Mounted into `/usr/share/nginx/html`.

#### ConfigMap: `nginx-conf`

Provides `default.conf` with:

- Document root: `/usr/share/nginx/html`
- SPA routing:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

- Proxy to backend:

```nginx
location /api/ {
  proxy_pass http://backend-service:80/api/;
  proxy_http_version 1.1;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
}

location /health {
  proxy_pass http://backend-service:80/health;
}

location = /api {
  proxy_pass http://backend-service:80/;
}
```

#### Deployment: `frontend`

- 2 replicas
- Image: `phanindhrasura/frontend:latest`
- Container port: `80`
- Resource requests/limits:
  - Requests: `50m` CPU, `64Mi` memory
  - Limits: `100m` CPU, `128Mi` memory
- Volumes:
  - `nginx-html` (ConfigMap `frontend-html`) → `/usr/share/nginx/html`
  - `nginx-config` (ConfigMap `nginx-conf`) → `/etc/nginx/conf.d`

#### Service: `frontend-service`

- Type: `NodePort`
- Port: `80`
- TargetPort: `80`
- `nodePort: 30080` (access via `NODE_IP:30080`)

#### Ingress: `app-ingress`

- Host: `devops-app.local`
- Routes:
  - `/` → `frontend-service:80`
  - `/api(/|$)(.*)` → `backend-service:80` (with rewrite via annotation `nginx.ingress.kubernetes.io/rewrite-target: /api/$2`)

***

## 📊 Monitoring Stack (Prometheus + Grafana)

All manifests under monitoring stack (namespace `monitoring`).

### Components

- Namespace: `monitoring`
- Prometheus:
  - ConfigMap with `prometheus.yml`
  - Deployment (1 replica)
  - NodePort service on `30090`
- Grafana:
  - Deployment (1 replica)
  - NodePort service on `30300`
  - Datasource ConfigMap (Prometheus)
  - Admin credentials:
    - `GF_SECURITY_ADMIN_USER=admin`
    - `GF_SECURITY_ADMIN_PASSWORD=admin123`
- kube‑state‑metrics:
  - Deployment + Service
  - ClusterRole/ClusterRoleBinding
- node‑exporter:
  - DaemonSet
  - ClusterIP service
  - Scrapes each node

### Prometheus Scrape Config

Key jobs configured:

- `prometheus` – self monitoring
- `kubernetes-pods` – discovery via pod annotations
- `backend-api` – static target:
  - Example target: `backend-service.default.svc.cluster.local:3000` (can be aligned with actual metrics port as needed)
- `frontend` – static target:
  - `frontend-service.default.svc.cluster.local:80`

### Monitoring Deploy Scripts

Two helper shell scripts (examples):

- Deploy everything from a single YAML (`monitoring-complete.yaml`)
- Or step‑by‑step deployment:
  - Namespace
  - Prometheus config, RBAC, deployment, service
  - Grafana datasource, deployment, service
  - kube‑state‑metrics
  - node‑exporter
  - Waits for pods ready and prints access URLs

Example outputs:

- `Prometheus: http://$(minikube ip):30090`
- `Grafana: http://$(minikube ip):30300`
- Quick commands:
  - `minikube service prometheus -n monitoring`
  - `minikube service grafana -n monitoring`

***

## 🔮 Terraform (Docker Provider Demo)

Location: Terraform folder.

### Purpose

Showcases **Infrastructure as Code** by provisioning multiple Nginx containers with Terraform using the **kreuzwerker/docker** provider.

### Provider

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}
```

### Resources

```hcl
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "nginx" {
  count = var.container_count

  image = docker_image.nginx.image_id
  name  = "terraform-nginx-${count.index + 1}"

  ports {
    internal = 80
    external = var.base_port + count.index
  }
}
```

### Variables

```hcl
variable "container_count" {
  description = "Number of nginx containers"
  type        = number
  default     = 3
}

variable "base_port" {
  description = "Starting port number"
  type        = number
  default     = 8080
}
```

### Example Usage

```bash
cd terraform
terraform init
terraform apply \
  -var="container_count=3" \
  -var="base_port=8080"
```

Result: Nginx containers on ports `8080`, `8081`, `8082`, etc.

***

## 🚀 How to Run (Minikube)

### Prerequisites

- Docker
- kubectl
- Minikube
- (Optional) Terraform for local Docker demo

### 1. Start Minikube

```bash
minikube start
```

### 2. Deploy Monitoring

```bash
cd monitoring
./deploy-monitoring.sh
```

Check status in namespace `monitoring`:

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Access:

- Prometheus: `http://$(minikube ip):30090`
- Grafana: `http://$(minikube ip):30300`  
  Login: `admin` / `admin123`

### 3. Deploy Application Stack

```bash
kubectl apply -f kubernetes/database/
kubectl apply -f kubernetes/backend/
kubectl apply -f kubernetes/frontend/
```

Check:

```bash
kubectl get pods
kubectl get svc
kubectl get ingress
```

### 4. Access the App

Options:

- NodePort:

  ```bash
  minikube service frontend-service
  ```

  or:

  ```bash
  echo "http://$(minikube ip):30080"
  ```

- Ingress (if Ingress controller + DNS or `/etc/hosts` entry):

  ```text
  http://devops-app.local
  ```

***

## 💡 Showcase Points (For Resume / Interviews)

- Full CI/CD pipeline with GitHub Actions building and pushing Docker images to Docker Hub.
- Backend with:
  - Proper health checks
  - MongoDB integration
  - Prometheus metrics on `/metrics`
- Frontend:
  - Nginx reverse proxy to backend
  - SPA routing
  - Health and status visualization
- Kubernetes:
  - Multi‑service setup (frontend, backend, database)
  - Ingress, NodePort, ClusterIP
  - Resource requests/limits
  - Persistent storage for MongoDB
- Monitoring:
  - Dedicated namespace
  - Prometheus, Grafana, kube‑state‑metrics, node‑exporter
- Terraform:
  - Docker provider demo for declarative container provisioning

You can now copy this entire README into `README.md` and adjust small details (like repository name and Docker Hub username) as needed.
