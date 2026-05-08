FROM ghcr.io/linuxserver/baseimage-ubuntu:jammy

# Set version label
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# Environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/config" 

# Install dependencies and clean up in a single RUN command
RUN apt-get update && apt-get install -y \
    git openssh-client jq libatomic1 nano net-tools netcat sudo \
    ca-certificates curl gnupg s3fs \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    && npx playwright install-deps \
    && npx playwright install webkit chromium \
    && if [ -z ${CODE_RELEASE+x} ]; then \
         CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
       fi \
    && mkdir -p /app/code-server \
    && curl -o /tmp/code-server.tar.gz -L "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" \
    && tar xf /tmp/code-server.tar.gz -C /app/code-server --strip-components=1 \
    && curl -o /tmp/ngrok.tgz -L "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz" \
    && tar zxvf /tmp/ngrok.tgz -C /app \
    && curl -LO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared-linux-amd64.deb \
    && mkdir -p /temp/extensions \
    && /app/code-server/bin/code-server --extensions-dir /temp/extensions --install-extension ms-azuretools.vscode-docker \
    && /app/code-server/bin/code-server --extensions-dir /temp/extensions --install-extension IronGeek.vscode-env \
    && /app/code-server/bin/code-server --extensions-dir /temp/extensions --install-extension esbenp.prettier-vscode \
    && /app/code-server/bin/code-server --extensions-dir /temp/extensions --install-extension redhat.vscode-yaml \
    && /app/code-server/bin/code-server --extensions-dir /temp/extensions --install-extension nick-rudenko.back-n-forth \
    && /app/code-server/bin/code-server --extensions-dir /temp/extensions --install-extension humao.rest-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* "${HOME:?}"/*

# Add local files
COPY /root /

# Expose port
EXPOSE 8443
