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

# Install some dependencies
RUN apt-get update \
  && apt-get install -y \
  gettext \
  tini \
  varnish \
  varnish-modules \
  && apt-get clean

# Deploy our custom configuration
WORKDIR /etc/varnish
COPY config/ /templates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 80 8443
ENTRYPOINT [ "tini", "--", "/entrypoint.sh" ]
