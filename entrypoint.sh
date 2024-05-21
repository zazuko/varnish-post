#!/bin/sh

ENABLE_LOGS="${ENABLE_LOGS}"

set -eu

# Environment variables substitution
for SRC_LOCATION in $(find /templates -type f); do
  DST_LOCATION=$(echo "${SRC_LOCATION}" | sed 's/^\/templates/\/etc\/varnish/')
  envsubst \
    < "${SRC_LOCATION}" \
    > "${DST_LOCATION}"
  echo "INFO: generated '${DST_LOCATION}' from '${SRC_LOCATION}' (environment variables substitution)"
done

# Display logs if configured
if [ "${ENABLE_LOGS}" = "true" ]; then
  varnishncsa&
fi

set -x

# Run Varnish
varnishd \
  -F \
  -f "/etc/varnish/${CONFIG_FILE}" \
  -a http=:80,HTTP \
  -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s "malloc,${VARNISH_SIZE}" \
  "$@"
