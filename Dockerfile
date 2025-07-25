# syntax=docker/dockerfile:1

ARG ECR_ACCOUNT_ID
ARG ECR_REGION=us-east-1
ARG BASE_IMAGE_NAME=docker-linuxserver-ubuntu-fips
ARG BASE_IMAGE_TAG=jammy-latest
ARG ECR_URI=${ECR_ACCOUNT_ID}.dkr.ecr-fips.${ECR_REGION}.amazonaws.com/${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

FROM ${ECR_URI} as docker-code-server-python

ARG DEBIAN_FRONTEND="noninteractive"

# Install Python 3.12
RUN echo "**** install Python 3.12 ****" && \
  apt-get update && \
  apt-get install -y \
    software-properties-common \
    gpg-agent && \
  curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xF23C5A6CF475977595C89F51BA6932366A755776 | apt-key add - && \
  echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes.list && \
  apt-get update && \
  apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv && \
  update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
  update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
  curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 && \
  pip3 install --upgrade pip setuptools wheel && \
  python3 --version && \
  pip3 --version && \
  echo "**** clean up ****" && \
  apt-get clean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /tmp/*

FROM docker-code-server-python
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE

LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="civisanalytics"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/config"

RUN \
  echo "**** install runtime dependencies ****" && \
  apt-get update && \
  apt-get install -y \
    git \
    libatomic1 \
    nano \
    net-tools \
    netcat-openbsd \
    sudo && \
  echo "**** install code-server ****" && \
  if [ -z ${CODE_RELEASE+x} ]; then \
    CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
      | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
  fi && \
  mkdir -p /app/code-server && \
  curl -o \
    /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
  tar xf /tmp/code-server.tar.gz -C \
    /app/code-server --strip-components=1 && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** clean up ****" && \
  apt-get clean && \
  rm -rf \
    /config/* \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 8443
