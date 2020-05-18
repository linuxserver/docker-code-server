FROM lsiobase/ubuntu:bionic

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# environment settings
ENV HOME="/config"

RUN \
 echo "**** install dependencies ****" && \
 apt-get update && \
 apt-get install -y \
	git \
	jq \
	nano \
 npm \
	net-tools \
	sudo && \
 echo "**** install code-server ****" && \
 if [ -z ${CODE_RELEASE+x} ]; then \
	CODE_RELEASE=$(curl -sX GET "https://api.github.com/repos/cdr/code-server/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 CODE_URL=$(curl -sX GET "https://api.github.com/repos/cdr/code-server/releases/tags/${CODE_RELEASE}" \
	| jq -r '.assets[] | select(.browser_download_url | contains("linux-amd64")) | .browser_download_url') && \
 mkdir -p /app/code-server && \
 curl -o \
	/tmp/code.tar.gz -L \
	"${CODE_URL}" && \
 tar xzf /tmp/code.tar.gz -C \
	/app/code-server --strip-components=1 && \
 cd /app/code-server && \
 npm rebuild spdlog && \
 echo "**** clean up ****" && \
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 8443
