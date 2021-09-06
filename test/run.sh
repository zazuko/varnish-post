#!/bin/sh

set -eux

BACKEND_ENDPOINT="http://localhost:8080"

# Display error message and exit
## $1: error message to display
error () {
  echo "ERROR: $1" >&2
  exit 1
}

# Display information message
## $1: info message to display
info () {
  echo "\n\nINFO: $1"
}

# Get time field from a JSON response
## $1: http url
fetch_time () {
  curl -sL "$1" | jq .time
}

# Start of the checks

## Check of required tools

info "Check jq command…"
res=$(echo '{"time": 42}' | jq .time)
if [ "${res}" -ne "42" ]; then
  error "jq command is not working"
fi

## Basic checks on the backend application

info "Check if backend application is up…"
curl -sL "${BACKEND_ENDPOINT}" 2>&1 >/dev/null

info "Check if timestamp is changing…"
res1=$(fetch_time "${BACKEND_ENDPOINT}")
res2=$(fetch_time "${BACKEND_ENDPOINT}")
if [ "${res1}" -eq "${res2}" ]; then
  error "timestamp is not changing"
fi
if [ "${res1}" -ge "${res2}" ]; then
  error "timestamp is not increasing"
fi

# If we are at this point, no test failed

info "All tests passed :)"
