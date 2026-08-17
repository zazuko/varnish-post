FROM docker.io/library/ubuntu:26.04

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
ENV PURGE_ACL="localhost"
ENV CUSTOM_ARGS=""

# Install some dependencies
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
  gettext \
  prometheus-varnish-exporter \
  tini \
  varnish \
  varnish-modules \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Deploy our custom configuration
WORKDIR /etc/varnish
COPY config/ /templates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 80 8443 9131
CMD [ "tini", "--", "/entrypoint.sh" ]
