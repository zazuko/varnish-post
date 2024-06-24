#!/bin/sh

ENABLE_LOGS="${ENABLE_LOGS}"
ENABLE_PROMETHEUS_EXPORTER="${ENABLE_PROMETHEUS_EXPORTER}"

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

# Start prometheus_varnish_exporter if enabled
if [ "${ENABLE_PROMETHEUS_EXPORTER}" = "true" ]; then
  (sleep 2 && prometheus_varnish_exporter \
    -web.listen-address ":9131" \
    -web.telemetry-path "/metrics") &
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
