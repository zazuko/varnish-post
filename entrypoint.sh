#!/bin/sh

# Every variable used here is given a default by the Dockerfile, so `set -u`
# reports a missing one instead of quietly treating it as disabled.
set -eu

# Variables the templates are allowed to reference.
#
# envsubst is restricted to this list on purpose. Left unrestricted it rewrites
# every `$NAME` it finds, so a configuration supplied through CONFIG_FILE would
# get `$HOME` replaced by the container's home directory, and any name that is
# not set silently replaced by an empty string.
#
# shellcheck disable=SC2016 # the literal `$NAME` tokens are what envsubst reads
TEMPLATE_VARS='$BACKEND_HOST $BACKEND_PORT $BACKEND_FIRST_BYTE_TIMEOUT $CACHE_TTL $BODY_SIZE $VARNISH_SIZE $DISABLE_ERROR_CACHING $DISABLE_ERROR_CACHING_TTL $CONFIG_FILE $ENABLE_LOGS $ENABLE_PROMETHEUS_EXPORTER $PURGE_ACL $CUSTOM_ARGS'

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
for SRC_LOCATION in /templates/*; do
  [ -f "${SRC_LOCATION}" ] || continue

  DST_LOCATION="/etc/varnish/$(basename "${SRC_LOCATION}")"
  envsubst "${TEMPLATE_VARS}" < "${SRC_LOCATION}" > "${DST_LOCATION}"
  echo "INFO: generated '${DST_LOCATION}' from '${SRC_LOCATION}' (environment variables substitution)"
done

# Fail with a readable message rather than letting varnishd complain about a
# file that was never generated.
if [ ! -f "/etc/varnish/${CONFIG_FILE}" ]; then
  echo "ERROR: configuration file '/etc/varnish/${CONFIG_FILE}' does not exist." >&2
  echo "ERROR: available configuration files: $(cd /etc/varnish && echo *)" >&2
  exit 1
fi

# Display logs if configured
#
# Requests served in the moment before varnishncsa attaches to the shared log
# are not recorded; it retries until varnishd has started its child.
if [ "${ENABLE_LOGS}" = "true" ]; then
  varnishncsa&
fi

# Start the Prometheus exporter if enabled
#
# The exporter survives being started too early -- it only reports the failure
# and recovers on the next scrape -- but it logs its startup test as an error,
# which is alarming for something that is expected. Waiting for varnishd to
# publish its statistics avoids that without guessing at a delay.
if [ "${ENABLE_PROMETHEUS_EXPORTER}" = "true" ]; then
  (
    while ! varnishstat -1 >/dev/null 2>&1; do
      sleep 0.2
    done

    prometheus-varnish-exporter \
      -web.listen-address ":9131" \
      -web.telemetry-path "/metrics"
  ) &
fi

# Display Varnish configuration
cat "/etc/varnish/${CONFIG_FILE}"

set -x

# Run Varnish
#
# `exec` hands the process over, so varnishd becomes the direct child of the
# init process and receives the signals that stop the container itself.
# shellcheck disable=SC2086 # CUSTOM_ARGS must split into separate arguments
exec varnishd \
  -F \
  -f "/etc/varnish/${CONFIG_FILE}" \
  -a http=:80,HTTP \
  -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s "malloc,${VARNISH_SIZE}" \
  ${CUSTOM_ARGS} \
  "$@"
