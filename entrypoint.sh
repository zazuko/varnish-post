#!/bin/sh

set -eu

# environment variables substitution
for SRC_LOCATION in $(find /templates -type f); do
  DST_LOCATION=$(echo "${SRC_LOCATION}" | sed 's/^\/templates/\/etc\/varnish/')
  envsubst \
    < "${SRC_LOCATION}" \
    > "${DST_LOCATION}"
  echo "INFO: generated '${DST_LOCATION}' from '${SRC_LOCATION}' (environment variables substitution)"
done

set -x

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
