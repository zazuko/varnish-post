FROM docker.io/library/alpine:3.15

# configuration
ENV BACKEND_HOST="localhost"
ENV BACKEND_PORT="3000"
ENV CACHE_TTL="3600s"
ENV BODY_SIZE="2048KB"
ENV BACKEND_FIRST_BYTE_TIMEOUT="60s"
ENV VARNISH_SIZE="100M"
ENV DISABLE_ERROR_CACHING="true"
ENV DISABLE_ERROR_CACHING_TTL="30s"
ENV CONFIG_FILE="default.vcl"

# install some dependencies
RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" \
  >> /etc/apk/repositories
RUN apk add --no-cache \
  gettext \
  tini \
  varnish \
  varnish-modules@testing

# deploy our custom configuration
WORKDIR /etc/varnish
COPY config/ /templates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 80 8443
ENTRYPOINT [ "tini", "--", "/entrypoint.sh" ]
