FROM docker.io/alpine:3.15

ENV BACKEND_HOST="localhost"
ENV BACKEND_PORT="3000"
ENV CACHE_TTL="3600s"
ENV BODY_SIZE="2048KB"
ENV BACKEND_FIRST_BYTE_TIMEOUT="60s"
ENV VARNISH_SIZE="100M"
ENV DISABLE_ERROR_CACHING="true"
ENV DISABLE_ERROR_CACHING_TTL="30s"

RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" \
  >> /etc/apk/repositories
RUN apk add --no-cache gettext varnish varnish-modules@testing

WORKDIR /etc/varnish

RUN mkdir -p /templates
COPY default.vcl /templates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 80 8443
CMD [ "/entrypoint.sh" ]
