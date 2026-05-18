FROM docker.io/debian:trixie-slim

ARG UNIFI_VERSION
ARG UNIFI_ZIP_URL

LABEL org.opencontainers.image.authors="Haythem Tlili <haythem.tlili@outlook.com>" \
    org.opencontainers.image.title="UniFi Network Application" \
    org.opencontainers.image.description="Ubiquiti UniFi Network Controller" \
    org.opencontainers.image.vendor="Custom" \
    org.opencontainers.image.version="${UNIFI_VERSION}" \
    org.opencontainers.image.source="https://github.com/haythem/unifi-network-application" \
    org.opencontainers.image.documentation="https://github.com/haythem/unifi-network-application/blob/main/README.md"

ENV DEBIAN_FRONTEND="noninteractive" \
    MONGO_PORT=27017 \
    MONGO_TLS=false \
    MEM_LIMIT=1024 \
    MEM_STARTUP=1024

COPY root/ /

RUN apt-get update && \
    # Dependencies
    apt-get install --no-install-recommends -y \
    curl unzip logrotate openjdk-21-jre-headless && \
    # Unifi Network Application
    curl -o /tmp/unifi.zip -L "${UNIFI_ZIP_URL}" && \
    unzip /tmp/unifi.zip -d /usr/lib && mv /usr/lib/UniFi /usr/lib/unifi && \
    # Cleanup
    apt-get -y clean && \
    rm -rf /usr/share/doc/* /usr/share/locale/* /usr/share/man/* /var/cache/apt/archives /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Directories & Permissions
    mkdir -p /config/data /config/logs && \
    ln -snf /config/data /usr/lib/unifi/data && \
    ln -snf /config/logs /usr/lib/unifi/logs && \
    chgrp -R 0 /config /defaults /usr/lib/unifi && \
    chmod -R g=u /config /usr/lib/unifi && \
    chmod 1777 /config && \
    chmod 775 /defaults && \
    chmod +x /entrypoint.sh

RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

WORKDIR /usr/lib/unifi
VOLUME /config
EXPOSE 8080/tcp 8443/tcp 3478/udp 10001/udp 8843/tcp 8880/tcp 6789/tcp

ENTRYPOINT ["/entrypoint.sh"]
