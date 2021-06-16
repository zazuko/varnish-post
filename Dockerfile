ARG VARNISH_PKG_VERSION="6.6"

FROM "docker.io/varnish:${VARNISH_PKG_VERSION}"

ENV BACKEND_HOST="localhost"
ENV BACKEND_PORT="3000"
ENV CACHE_TTL="3600s"
ENV BODY_SIZE="2048KB"

ARG VARNISH_PKG_VERSION

RUN apt-get update && apt-get install -y build-essential automake libtool git python-docutils varnish-dev pkg-config libvarnishapi1 autotools-dev gettext
RUN git clone --branch "${VARNISH_PKG_VERSION}" --single-branch https://github.com/varnish/varnish-modules.git /tmp/vm

WORKDIR /tmp/vm

RUN ./bootstrap \
  && ./configure \
  && make \
  && make check \
  && make install \
  && rm -rf /tmp/vm

WORKDIR /etc/varnish

RUN mkdir -p /templates
COPY default.vcl /templates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 80 8443
ENTRYPOINT [ "/entrypoint.sh" ]
CMD []
