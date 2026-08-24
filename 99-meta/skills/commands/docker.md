# Docker Technical Workflow

**Date:** 2026-05-19

---

## 1. Goal

Standardized Docker workflow for greenfield projects — from local dev (hot-reload) to production (lean image) using the Docker Compose override pattern.

---

## 2. File Structure

```
project-root/
├── Dockerfile              # multi-stage build
├── docker-compose.yml      # base config
├── docker-compose.dev.yml  # dev override (volumes, ports, env)
├── docker-compose.prod.yml # prod override (resource limits, restart policy)
├── .env.example            # env template, committed to git
├── .env                    # real values, gitignored
└── Makefile                # shortcut commands
```

---

## 3. Dockerfile — Multi-stage Build

```dockerfile
# Stage 1: Build
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /app/server ./cmd/main.go

# Stage 2: Runtime
FROM alpine:3.19
RUN adduser -D nonroot
COPY --from=builder /app/server /app/server
USER nonroot
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/server"]
```

**Why multi-stage?**
- Build stage uses `golang:alpine` — full toolchain to compile.
- Runtime stage uses only `alpine:3.19` — no source code exposed, no compiler, image < 20MB for Go.

---

## 4. docker-compose.yml (Base)

```yaml
version: "3.9"

networks:
  app-net:
    driver: bridge

volumes:
  pgdata:

services:
  api:
    build: .
    networks:
      - app-net
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    networks:
      - app-net
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
```

---

## 5. docker-compose.dev.yml (Dev Override)

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.dev   # uses go + air image, not multi-stage
    networks:
      - app-net
    volumes:
      - ./:/app                    # mount source for hot-reload
    ports:
      - "8080:8080"
    environment:
      APP_ENV: development

  db:
    networks:
      - app-net
    ports:
      - "5432:5432"               # expose to host for DB clients (TablePlus, DBeaver)

networks:
  app-net:
    external: true               # reuse network declared in base compose
```

**Run dev:**
```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
# or: make dev
```

---

## 6. docker-compose.prod.yml (Prod Override)

```yaml
services:
  api:
    image: myapp:latest            # use pre-built image, don't rebuild
    networks:
      - app-net
    restart: unless-stopped
    ports:
      - "8080:8080"
    deploy:
      resources:
        limits:
          memory: 256M
    environment:
      APP_ENV: production

  db:
    networks:
      - app-net
    restart: unless-stopped
    # DO NOT expose port to host

networks:
  app-net:
    external: true               # reuse network declared in base compose
```

**Run prod:**
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
# or: make prod
```

---

## 7. Makefile

```makefile
.PHONY: dev prod build down health logs

dev:
	docker compose -f docker-compose.yml -f docker-compose.dev.yml up

prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

build:
	docker build -t myapp:latest .

down:
	docker compose down

health:
	curl -f http://localhost:8080/health && echo " OK" || echo " FAIL"

logs:
	docker compose logs -f api
```

---

## 8. .env.example

```env
# App
APP_ENV=development
PORT=8080

# Database
DB_HOST=db
DB_PORT=5432
DB_USER=appuser
DB_PASSWORD=changeme
DB_NAME=appdb
DB_URL=postgres://appuser:changeme@db:5432/appdb?sslmode=disable
```

> `.env` is gitignored, `.env.example` is committed — teammates know what to set after cloning.

---

## 9. Dockerfile.dev (hot-reload with air)

```dockerfile
FROM golang:1.23-alpine
WORKDIR /app
RUN go install github.com/air-verse/air@latest
COPY go.mod go.sum ./
RUN go mod download
CMD ["air", "-c", ".air.toml"]
```

**.air.toml** (place at root):
```toml
root = "."
tmp_dir = "tmp"

[build]
cmd = "go build -o ./tmp/main ./cmd/main.go"
bin = "./tmp/main"
include_ext = ["go"]
exclude_dir = ["tmp", "vendor"]
delay = 1000
```

---

## 10. Quick Start (3 commands)

```bash
cp .env.example .env        # 1. setup env
make dev                    # 2. start stack
make health                 # 3. verify
```

---

## 11. Services Reference

| Service | Image | Port (dev) | Port (prod) | Volume |
|---|---|---|---|---|
| api | custom multi-stage | 8080 | 8080 | src (dev only) |
| db | postgres:16-alpine | 5432 | - (internal) | pgdata |

---

## 12. .dockerignore

Place at project root — reduces build context sent to the Docker daemon for faster builds and prevents sensitive files from leaking into the image.

```dockerignore
# Git
.git
.gitignore

# Env & secrets
.env
.env.*
!.env.example

# Docker files (not needed inside image)
Dockerfile*
docker-compose*.yml

# Dev tooling
.air.toml
tmp/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Test & coverage
*_test.go
coverage.out
*.test

# Docs
*.md
docs/

# Node (if frontend exists)
node_modules/
dist/
.next/
```

**Rules:**
- `!.env.example` — exception: allow the example file into context (not a secret).
- Always have `.dockerignore` before running `docker build` — without it, the entire `.git` directory gets copied into the context.

---

## 13. Persistent Volumes on Production

> **Rule**: Named volumes (`pgdata:`) live inside the Docker daemon — deleted by `docker system prune -v`. On prod, mount directly to a **host path** so data survives independently of Docker.

### docker-compose.prod.yml — host mount (full version)

```yaml
services:
  api:
    image: myapp:latest
    networks:
      - app-net
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /opt/myapp/logs:/app/logs          # app logs
      - /opt/myapp/uploads:/app/uploads    # uploaded files / media
    environment:
      APP_ENV: production

  db:
    image: postgres:16-alpine
    networks:
      - app-net                            # must share network to communicate with api
    restart: unless-stopped
    volumes:
      - /opt/myapp/postgres:/var/lib/postgresql/data  # DB data to host path
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}

networks:
  app-net:
    external: true                         # reuse network from base compose
```

### Setup host path before running

```bash
# Create directories on prod VPS (run once during setup)
sudo mkdir -p /opt/myapp/postgres
sudo mkdir -p /opt/myapp/logs
sudo mkdir -p /opt/myapp/uploads

# Postgres requires correct ownership (uid 999 = postgres user in alpine image)
sudo chown -R 999:999 /opt/myapp/postgres
```

### Named Volume vs Host Mount Comparison

| | Named Volume | Host Mount (prod) |
|---|---|---|
| Location | `/var/lib/docker/volumes/` | `/opt/myapp/...` (under your control) |
| Deleted by `docker system prune -v` | **Yes** | No |
| Direct backup with `cp`/`rsync` | Hard | Easy |
| Use on dev | Fine | Not needed |
| Use on prod | **Avoid** | **Required** |

### Backup data

```bash
# Backup postgres
sudo rsync -av /opt/myapp/postgres/ /backup/postgres-$(date +%Y%m%d)/

# Backup uploads
sudo rsync -av /opt/myapp/uploads/ /backup/uploads-$(date +%Y%m%d)/
```

---

## 14. Push Image to Docker Hub

### Setup (once)

```bash
# Log in to Docker Hub
docker login

# Or use an access token (recommended — avoid using password)
docker login -u <username> --password-stdin <<< "<access_token>"
```

> Create an access token at: **Docker Hub → Account Settings → Security → New Access Token**. Select scope `Read & Write`.

### Build + Tag + Push

```bash
# Build image with a specific tag (use semver, never use latest on prod)
docker build -t myapp:v1.3.0 .

# Tag for Docker Hub
docker tag myapp:v1.3.0 <username>/myapp:v1.3.0
docker tag myapp:v1.3.0 <username>/myapp:latest

# Push to Hub
docker push <username>/myapp:v1.3.0
docker push <username>/myapp:latest
```

### Add to Makefile

```makefile
DOCKER_USER ?= yourname
APP_NAME    ?= myapp
VERSION     ?= $(shell git describe --tags --abbrev=0)

push:
	docker build -t $(DOCKER_USER)/$(APP_NAME):$(VERSION) .
	docker tag $(DOCKER_USER)/$(APP_NAME):$(VERSION) $(DOCKER_USER)/$(APP_NAME):latest
	docker push $(DOCKER_USER)/$(APP_NAME):$(VERSION)
	docker push $(DOCKER_USER)/$(APP_NAME):latest
```

```bash
make push VERSION=v1.3.0
```

### Use Hub image on Prod VPS

Update `docker-compose.prod.yml`:

```yaml
services:
  api:
    image: <username>/myapp:v1.3.0   # pull from Docker Hub instead of local build
```

```bash
# On prod VPS — pull new image and restart
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
# or: make prod
```

### Private repo

If the image contains code that should not be public:

```bash
# Create a private repo on Docker Hub UI first, then push normally
# Prod VPS needs to log in to Docker Hub to pull private images
ssh my-vps-prod "docker login -u <username> --password-stdin" <<< "<access_token>"
```

---

## 15. Container Permissions (Security Hardening)

### Layer 1 — Linux User/Group

**In Dockerfile** (applies to all environments):

```dockerfile
FROM alpine:3.19

# Create dedicated group + user, no home dir, no login shell
RUN addgroup -S appgroup && adduser -S -G appgroup -H -s /sbin/nologin appuser

WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/server /app/server

# File permissions: owner is appuser, group is appgroup
RUN chmod 550 /app/server         # r-xr-x--- only owner + group can execute

USER appuser
```

**In docker-compose.prod.yml** — enforce at runtime:

```yaml
services:
  api:
    image: <username>/myapp:v1.3.0
    user: "1001:1001"              # uid:gid of appuser — prevents root override
    read_only: true                # read-only filesystem, only volumes are writable
    tmpfs:
      - /tmp:size=64m,mode=1777   # /tmp is still writable (needed by processes), limited to 64MB
    volumes:
      - /opt/myapp/logs:/app/logs
      - /opt/myapp/uploads:/app/uploads

  db:
    image: postgres:16-alpine
    user: "999:999"               # postgres uid in alpine image
```

> Check actual uid: `docker run --rm postgres:16-alpine id postgres`

---

### Layer 2 — Docker Capabilities

Drop all capabilities, add back only what is actually needed:

```yaml
services:
  api:
    image: <username>/myapp:v1.3.0
    cap_drop:
      - ALL                        # drop all Linux capabilities
    cap_add:
      - NET_BIND_SERVICE           # only add if app binds a port < 1024 (not needed for port 8080+)
    security_opt:
      - no-new-privileges:true     # child processes cannot escalate privileges (setuid/setgid)
      - seccomp:unconfined         # replace with a custom seccomp profile for stricter enforcement

  db:
    image: postgres:16-alpine
    cap_drop:
      - ALL
    cap_add:
      - CHOWN                      # postgres needs chown on data files during init
      - DAC_OVERRIDE               # read/write files regardless of owner
      - FOWNER                     # change file permissions
      - SETUID                     # switch uid internally (postgres → worker process)
      - SETGID
    security_opt:
      - no-new-privileges:true
```

**Capabilities quick reference:**

| Capability | Allows | Needed? |
|---|---|---|
| `NET_BIND_SERVICE` | Bind port < 1024 | No if using port 8080+ |
| `CHOWN` | `chown` files | DB init only |
| `DAC_OVERRIDE` | Bypass file permission checks | DB only |
| `SETUID` / `SETGID` | Switch uid/gid | DB worker only |
| `SYS_ADMIN` | Mount, namespaces... | **Never on prod** |
| `NET_RAW` | Raw socket, ping | Not needed for web app |

---

### docker-compose.prod.yml — Full Security Config

```yaml
services:
  api:
    image: <username>/myapp:v1.3.0
    networks:
      - app-net
    restart: unless-stopped
    user: "1001:1001"
    read_only: true
    tmpfs:
      - /tmp:size=64m,mode=1777
    ports:
      - "8080:8080"
    volumes:
      - /opt/myapp/logs:/app/logs
      - /opt/myapp/uploads:/app/uploads
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    environment:
      APP_ENV: production
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: "1.0"

  db:
    image: postgres:16-alpine
    networks:
      - app-net
    restart: unless-stopped
    user: "999:999"
    volumes:
      - /opt/myapp/postgres:/var/lib/postgresql/data
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - FOWNER
      - SETUID
      - SETGID
    security_opt:
      - no-new-privileges:true
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    deploy:
      resources:
        limits:
          memory: 512M

networks:
  app-net:
    external: true
```

---

### Verify after running

```bash
# Check which user the container is running as
docker compose exec api whoami
docker compose exec api id

# Check actual capabilities of the container
docker inspect <container_id> | grep -A 20 "CapAdd\|CapDrop"

# Test read_only — must fail
docker compose exec api touch /test.txt   # expected: Read-only file system
docker compose exec api touch /tmp/test.txt  # expected: OK (tmpfs)
```

---

## 16. Pre-deploy Checklist

- [ ] `.env` is not committed to git (check `.gitignore`)
- [ ] `docker build` succeeds, image size < 50MB (Go)
- [ ] `make health` returns OK after `make prod`
- [ ] DB volume persists after `make down && make prod`
- [ ] DB port is NOT exposed in prod compose
- [ ] `USER nonroot` in Dockerfile — process does not run as root
- [ ] Resource limits set in prod compose

---

## 17. Anti-patterns (avoid)

| Wrong | Right |
|---|---|
| `COPY . .` before `go mod download` | Copy `go.mod go.sum` first → effective layer caching |
| Hardcoding secrets in Dockerfile | Use `env_file` + `.env` |
| Using `latest` tag for DB image | Pin version: `postgres:16-alpine` |
| Expose DB port in prod | Only expose in dev override |
| Single-stage build | Multi-stage — separate build and runtime |
| Running container as root | `USER nonroot` in runtime stage |
