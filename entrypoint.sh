#!/bin/sh

set -eux

# generate configuration file
envsubst \
  < /templates/default.vcl \
  > /etc/varnish/default.vcl

# run varnish
varnishd \
  -F \
  -f /etc/varnish/default.vcl \
  -a http=:80,HTTP \
  -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s "malloc,${VARNISH_SIZE}" \
  "$@"

# use following to debug hashes
#   -p vsl_mask=+Hash \
