#!/bin/sh

ENABLE_LOGS="${ENABLE_LOGS}"
ENABLE_PROMETHEUS_EXPORTER="${ENABLE_PROMETHEUS_EXPORTER}"
CUSTOM_ARGS="${CUSTOM_ARGS}"

set -eu

# Function to transform a host into a VCL-friendly format
transform_host() {
  input="$1"

  # Check if input is in CIDR notation (e.g., 0.0.0.0/0)
  if echo "$input" | grep -q "/"; then
    ip_part=$(echo "$input" | cut -d'/' -f1)
    cidr_part=$(echo "$input" | cut -d'/' -f2)
    echo "\"$ip_part\"/$cidr_part"
  else
    # Otherwise, it's a regular hostname or IP
    echo "\"$input\""
  fi
}
PURGE_ACL=$(transform_host "${PURGE_ACL}")

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

# Display Varnish configuration
cat "/etc/varnish/${CONFIG_FILE}"

set -x

# Run Varnish
varnishd \
  -F \
  -f "/etc/varnish/${CONFIG_FILE}" \
  -a http=:80,HTTP \
  -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s "malloc,${VARNISH_SIZE}" \
  "${CUSTOM_ARGS}" \
  "$@"
