# UniFi Controller Docker Image

This repository contains a custom container image for the Ubiquiti UniFi Network Application.

It is based on and inspired by `linuxserver/unifi-network-application`.
Thanks to the LinuxServer.io team for their work on the upstream image.

The motivation for this image is to provide a completely rootless experience with Podman and Docker,
and to support preserving the permissions of the rootless user over mounted volumes.

## Build

```bash
docker build -t unifi-controller .
```

## Run with Docker CLI

```bash
docker run -d \
  --name unifi-controller \
  --userns=keep-id \
  --user 1000:1000 \
  -p 3478:3478/udp \
  -p 10001:10001/udp \
  -p 8080:8080/tcp \
  -p 8443:8443/tcp \
  -p 8880:8880/tcp \
  -p 8843:8843/tcp \
  -p 6789:6789/tcp \
  -v /path/to/unifi/config:/config \
  -e PUID=1000 \
  -e PGID=1000 \
  -e MONGO_HOST=unifi-db \
  -e MONGO_PORT=27017 \
  -e MONGO_DBNAME=unifi \
  -e MONGO_AUTHSOURCE=admin \
  -e MONGO_USER=unifi \
  -e MONGO_PASS= \
  unifi-controller
```

`--userns=keep-id` preserves your host user identity inside the container when supported by your Docker daemon.

## Ports

- `8443/tcp` - UniFi web admin UI
- `3478/udp` - STUN port used for device discovery and connection
- `10001/udp` - Required for access point discovery on the local network
- `8080/tcp` - Device communication port used by UniFi devices
- `8843/tcp` - Guest portal HTTPS redirect
- `8880/tcp` - Guest portal HTTP redirect
- `6789/tcp` - Mobile speed test and remote access port
- `1900/udp` - Optional for L2 network discovery when required
- `5514/udp` - Optional remote syslog port

## MongoDB Requirement

This container requires an external MongoDB instance. Set the `MONGO_HOST`, `MONGO_PORT`, `MONGO_DBNAME`, `MONGO_AUTHSOURCE`, `MONGO_USER`, and `MONGO_PASS` environment variables to connect to your database.

The UniFi Network Application does not run without a working MongoDB backend.

## Run with Docker Compose

```yaml
version: '3.8'
services:
  unifi:
    image: unifi-controller
    container_name: unifi-controller
    user: "1000:1000"
    userns_mode: "keep-id"
    ports:
      - "3478:3478/udp"
      - "10001:10001/udp"
      - "8080:8080/tcp"
      - "8443:8443/tcp"
      - "8880:8880/tcp"
      - "8843:8843/tcp"
      - "6789:6789/tcp"
    volumes:
      - /path/to/unifi/config:/config
    environment:
      PUID: 1000
      PGID: 1000
      MONGO_HOST: unifi-db
      MONGO_PORT: 27017
      MONGO_DBNAME: unifi
      MONGO_AUTHSOURCE: admin
      MONGO_USER: unifi
      MONGO_PASS: ""
```

## Notes

- Replace `/path/to/unifi/config` with a real data directory on your host.
- Adjust `user` and `PUID`/`PGID` values to match the desired host user.
- Ensure `--userns=keep-id` is supported by your Docker version and configured properly.
- Ensure your MongoDB instance is reachable from the container and is configured with a UniFi-compatible database user.
