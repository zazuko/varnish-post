# Build the prometheus_varnish_exporter binary
FROM docker.io/library/golang:1.22 as prometheus_varnish_exporter
WORKDIR /app

# Releases: https://github.com/jonnenauha/prometheus_varnish_exporter/releases
ARG PROMETHEUS_VARNISH_EXPORTER_VERSION=1.6.1

RUN git clone https://github.com/jonnenauha/prometheus_varnish_exporter.git . \
  && git checkout "${PROMETHEUS_VARNISH_EXPORTER_VERSION}" \
  && go mod download \
  && go build -o prometheus_varnish_exporter

# Build the final image
FROM docker.io/library/ubuntu:22.04

# Configuration
ENV BACKEND_HOST="localhost"
ENV BACKEND_PORT="3000"
ENV CACHE_TTL="3600s"
ENV BODY_SIZE="2048KB"
ENV BACKEND_FIRST_BYTE_TIMEOUT="60s"
ENV VARNISH_SIZE="100M"
ENV DISABLE_ERROR_CACHING="true"
ENV DISABLE_ERROR_CACHING_TTL="30s"
ENV CONFIG_FILE="default.vcl"
ENV ENABLE_LOGS="true"
ENV ENABLE_PROMETHEUS_EXPORTER="false"

# Install some dependencies
RUN apt-get update \
  && apt-get install -y \
  gettext \
  tini \
  varnish \
  varnish-modules \
  && apt-get clean

# Get the prometheus_varnish_exporter binary
COPY --from=prometheus_varnish_exporter \
  /app/prometheus_varnish_exporter \
  /usr/local/bin/prometheus_varnish_exporter

# Deploy our custom configuration
WORKDIR /etc/varnish
COPY config/ /templates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 80 8443 9131
ENTRYPOINT [ "tini", "--", "/entrypoint.sh" ]
