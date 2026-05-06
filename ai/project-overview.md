# Project Overview: code-server Docker Container

## Quick Summary

This repository builds a Docker container image for [code-server](https://coder.com) - Visual Studio Code running on a remote server accessible via web browser.

**Status**: Active maintenance by LinuxServer.io team
**Base**: Ubuntu Jammy with s6-overlay process supervisor
**Application**: code-server (VS Code in browser)
**Port**: 8443
**Architectures**: x86_64, ARM64

## What is code-server?

code-server is VS Code running on a remote server, accessible through the browser. It allows developers to:
- Code on Chromebooks, tablets, and laptops with a consistent dev environment
- Develop for Linux more easily from Windows/Mac workstations
- Leverage large cloud servers for faster builds and tests
- Preserve battery life on laptops
- Run intensive computations on the server instead of local machine

## Project Structure

```
./
├── Dockerfile              # Main build configuration (x86_64)
├── Dockerfile.aarch64      # ARM64 build configuration
├── docker-compose.yml      # Development configuration
├── README.md               # Official documentation
├── Jenkinsfile             # CI/CD pipeline
├── .env.example            # Environment variable examples
├── root/                   # Files copied into container image
│   ├── etc/s6-overlay/      # Service definitions
│   │   └── s6-rc.d/
│   │       ├── svc-code-server/run    # Main service
│   │       └── init-code-server/run    # Init service
│   └── usr/local/bin/install-extension  # Extension installer
└── .github/workflows/      # GitHub Actions
```

## Key Components

### 1. Docker Image Structure
- **Base Image**: `ghcr.io/linuxserver/baseimage-ubuntu:jammy`
- **Process Supervisor**: s6-overlay (for reliable service management)
- **Application**: code-server (VS Code in browser)
- **User**: Runs as user `abc` (UID 1000) by default
- **Home Directory**: `/config`

### 2. Service Architecture (s6-overlay)

Two main services:

**init-code-server** (runs first):
- Sets up authentication
- Configures S3 workspace if enabled
- Prepares environment variables

**svc-code-server** (main service):
- Binds to `0.0.0.0:8443`
- Uses `/config` for all persistent data
- Supports multiple authentication modes
- Disables telemetry by default

### 3. Installed Components

**Build Tools:**
- Node.js 22.x
- yarn
- npm
- Playwright (for browser automation)
- Docker CLI and Docker Compose plugin

**Pre-installed Extensions:**
- ms-azuretools.vscode-docker
- IronGeek.vscode-env
- esbenp.prettier-vscode
- redhat.vscode-yaml
- nick-rudenko.back-n-forth
- humao.rest-client

**Utilities:**
- git, openssh-client, jq
- nano, sudo, curl, wget
- s3fs (for S3 integration)
- ngrok (for tunneling)
- cloudflared (for Cloudflare Tunnel)

## Environment Variables

### Core Configuration
| Variable | Purpose | Example |
|----------|---------|---------|
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `TZ` | Timezone | `Etc/UTC` |

### Authentication
| Variable | Purpose | Example |
|----------|---------|---------|
| `PASSWORD` | Plain text password | `mypassword` |
| `HASHED_PASSWORD` | Hashed password (overrides PASSWORD) | `$2a$10$...` |
| `SUDO_PASSWORD` | Password for sudo in terminal | `mypassword` |
| `SUDO_PASSWORD_HASH` | Hashed sudo password | `$2a$10$...` |

### Workspace & Networking
| Variable | Purpose | Example |
|----------|---------|---------|
| `DEFAULT_WORKSPACE` | Default workspace directory | `/config/workspace` |
| `PROXY_DOMAIN` | Domain for subdomain proxying | `code-server.my.domain` |

### S3 Integration (Optional)
When these are set, code-server creates a default workspace that mounts S3:
| Variable | Purpose | Example |
|----------|---------|---------|
| `S3_ACCESS_KEY_ID` | AWS/S3 access key | `AKIA...` |
| `S3_SECRET_ACCESS_KEY` | AWS/S3 secret key | `secret...` |
| `S3_BUCKET` | S3 bucket name | `code-server` |
| `S3_ENDPOINT` | S3 endpoint URL | `s3.amazonaws.com` |
| `S3_REGION` | S3 region | `us-east-1` |

### Git Configuration
| Variable | Purpose | Example |
|----------|---------|---------|
| `GIT_USER_NAME` | Git username | `John Doe` |
| `GIT_USER_EMAIL` | Git email | `john@example.com` |

### Cloud Services
| Variable | Purpose | Example |
|----------|---------|---------|
| `TOKEN_NGROK` | ngrok authentication token | `12345abcde` |
| `EXTENSIONS_RUNTIME` | Extensions to install at runtime | `Vue.volar dbaeumer.vscode-eslint` |

## Build & Deployment

### Building the Image

**Standard (x86_64):**
```bash
docker build --no-cache --pull -t lscr.io/linuxserver/code-server:latest .
```

**ARM64:**
```bash
# Register QEMU first
docker run --rm --privileged multiarch/qemu-user-static:register --reset

# Then build
docker build --no-cache --pull -t lscr.io/linuxserver/code-server:latest -f Dockerfile.aarch64 .
```

**With specific version:**
```bash
docker build --build-arg CODE_RELEASE=4.24.0 -t lscr.io/linuxserver/code-server:4.24.0 .
```

### Running the Container

**Basic:**
```bash
docker run -d \
  --name=code-server \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 8443:8443 \
  -v /path/to/config:/config \
  lscr.io/linuxserver/code-server:latest
```

**With authentication:**
```bash
docker run -d \
  --name=code-server \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e PASSWORD=mysecurepassword \
  -p 8443:8443 \
  -v /path/to/config:/config \
  lscr.io/linuxserver/code-server:latest
```

**With S3 workspace:**
```bash
docker run -d \
  --name=code-server \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e S3_ACCESS_KEY_ID=AKIA... \
  -e S3_SECRET_ACCESS_KEY=secret... \
  -e S3_BUCKET=my-bucket \
  -e S3_ENDPOINT=s3.amazonaws.com \
  -e S3_REGION=us-east-1 \
  -p 8443:8443 \
  -v /path/to/config:/config \
  lscr.io/linuxserver/code-server:latest
```

## Development Workflow

### 1. Clone the Repository
```bash
git clone https://github.com/linuxserver/docker-code-server.git
cd docker-code-server
```

### 2. Make Changes
- Modify `Dockerfile` for new packages/extensions
- Update service definitions in `root/etc/s6-overlay/s6-rc.d/`
- Test locally with `docker-compose up --build`

### 3. Test Your Changes
```bash
# Build and run
docker-compose up --build

# Access at http://localhost:8443

# Shell into container
docker exec -it code-server /bin/bash

# View logs
docker logs -f code-server
```

### 4. Install Extensions at Runtime
```bash
# Install via helper script
docker exec -it code-server install-extension ms-python.python

# Or via code-server CLI
docker exec -it code-server /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension ms-python.python
```

## Key Files to Understand

### Dockerfile (lines 1-47)
**What it does:**
- Sets up base Ubuntu Jammy image
- Installs all dependencies (apt packages, Node.js, Docker CLI)
- Downloads and configures code-server
- Installs extensions at build time
- Cleans up apt cache

**Key sections:**
- Lines 15-28: Package installation
- Lines 29-34: code-server download and extraction
- Lines 40-45: Extension installation

### svc-code-server/run (root/etc/s6-overlay/s6-rc.d/svc-code-server/run)
**What it does:**
- Defines the main code-server service
- Configures authentication
- Sets up workspace
- Starts code-server with proper arguments

**Key settings:**
- `--bind-addr 0.0.0.0:8443` - Makes it accessible from outside container
- `--user-data-dir /config/data` - Persistent user data
- `--extensions-dir /config/extensions` - Persistent extensions
- `--auth` - Authentication mode (password/none)

### install-extension (root/usr/local/bin/install-extension)
**What it does:**
- Helper script for installing extensions at runtime
- Runs as the correct user (abc)
- Usage: `install-extension extension-name@version`

## CI/CD Pipeline

**Platform**: Jenkins (managed by LinuxServer.io team)

**Pipeline Stages:**
1. **Build**: Creates Docker images for x86_64 and ARM64
2. **Test**: Validates the build works correctly
3. **Publish**: Pushes images to:
   - Docker Hub: `lscr.io/linuxserver/code-server`
   - GitHub Container Registry
   - Quay.io
4. **Cleanup**: Removes old images

**Build Frequency**: Weekly base OS updates, plus updates when code-server releases new versions

## Common Use Cases

### 1. Personal Development Environment
```bash
docker run -d \
  --name=code-server \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=America/New_York \
  -e PASSWORD=mysecurepassword \
  -e DEFAULT_WORKSPACE=/config/workspace \
  -p 8443:8443 \
  -v ~/code-server-config:/config \
  lscr.io/linuxserver/code-server:latest
```

### 2. Team Development Server
```bash
docker run -d \
  --name=code-server \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -e HASHED_PASSWORD='$2a$10$...' \
  -e PROXY_DOMAIN=code.company.com \
  -p 8443:8443 \
  -v /mnt/shared/config:/config \
  --restart unless-stopped \
  lscr.io/linuxserver/code-server:latest
```

### 3. Cloud Development with S3 Storage
```bash
docker run -d \
  --name=code-server \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -e S3_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e S3_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e S3_BUCKET=dev-bucket \
  -e S3_ENDPOINT=s3.us-east-1.amazonaws.com \
  -e S3_REGION=us-east-1 \
  -e GIT_USER_NAME="Dev Team" \
  -e GIT_USER_EMAIL="dev@company.com" \
  -p 8443:8443 \
  -v /mnt/code-server:/config \
  --restart unless-stopped \
  lscr.io/linuxserver/code-server:latest
```

## Troubleshooting

### Can't access web UI
**Check:**
- Container is running: `docker ps`
- Port is mapped: `docker port code-server` should show `8443/tcp -> 0.0.0.0:8443`
- No firewall blocking port 8443
- Try `http://localhost:8443` or `http://<container-ip>:8443`

### Authentication not working
**Check:**
- If using password, ensure `PASSWORD` or `HASHED_PASSWORD` is set
- If using no auth, ensure neither is set
- Hashed passwords must be properly formatted (use code-server's hashing tool)

### Extensions missing
**Check:**
- Extensions directory exists: `/config/extensions`
- Correct permissions: owned by user abc (UID 1000)
- Try installing via `install-extension` script

### Slow startup with large workspace
**Note:** Workspace directory contents are NOT chowned during startup (performance optimization)

### Permission issues
**Solution:** Use `PUID` and `PGID` environment variables to match your host user

## Version Management

**code-server versions** are tracked in the Dockerfile and can be updated by:
1. Setting `CODE_RELEASE` build arg
2. Or letting the Dockerfile auto-detect latest via GitHub API

**Container image versions** follow the pattern: `YYYY.MM.DD`

## Security Considerations

- **Authentication**: Always set a password or hashed password for production
- **File Permissions**: Use `PUID`/`PGID` to match host user
- **Sensitive Data**: Use Docker secrets or environment files for credentials
- **SSH Keys**: Mount to `/config/.ssh` for GitHub integration
- **Network**: Bind to specific IP if not using 0.0.0.0

## Performance Tips

- Use SSD storage for `/config` volume
- Allocate sufficient memory (code-server can use 1GB+)
- Consider CPU limits for shared environments
- Disable telemetry: `--disable-telemetry` flag in service definition

## Resources & Links

- **code-server**: https://coder.com / https://github.com/coder/code-server
- **s6-overlay**: https://github.com/just-containers/s6-overlay
- **LinuxServer.io**: https://linuxserver.io
- **Docker Multi-arch**: https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md
- **VS Code Extensions**: https://marketplace.visualstudio.com/vscode

## Quick Reference

| Task | Command |
|------|---------|
| Build image | `docker build -t my-code-server .` |
| Run container | `docker run -d -p 8443:8443 -v /config:/config my-code-server` |
| Shell access | `docker exec -it code-server /bin/bash` |
| View logs | `docker logs -f code-server` |
| Install extension | `docker exec -it code-server install-extension ms-python.python` |
| Update image | `docker pull lscr.io/linuxserver/code-server:latest` |

---

**Last Updated**: May 2026  
**Maintainer**: LinuxServer.io team  
**License**: OSS (see LICENSE file)
