#!/bin/sh

set -eux

BACKEND_ENDPOINT="http://localhost:8080"
CACHED_ENDPOINT="http://localhost:8081"

# Some useful functions

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

# Get time field from a JSON response using a POST request
## $1: http url
fetch_time_post () {
  curl -sL \
    -X POST \
    -H "Content-Type: application/json" \
    "$1" \
    --data '{"foo": "bar"}' | jq .time
}

# Get time field from a JSON response
## $1: http url
## $2: basic token
fetch_auth_time () {
  curl -sL -H "Authorization: Basic $2" "$1" | jq .time
}

# Get time field from a JSON response using a POST request
## $1: http url
## $2: basic token
fetch_auth_time_post () {
  curl -sL \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $2" \
    "$1" \
    --data '{"foo": "bar"}' | jq .time
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

# Start tests on the cached endpoint

info "Check if cached endpoint is up…"
curl -sL "${CACHED_ENDPOINT}" 2>&1 >/dev/null

info "Check if it can cache basic page…"
res1=$(fetch_time "${CACHED_ENDPOINT}")
res2=$(fetch_time "${CACHED_ENDPOINT}")
if [ "${res1}" -ne "${res2}" ]; then
  error "timestamp is changing => page is not cached"
fi

info "Check if TTL is working as expected (assuming CACHE_TTL=2s)…"
sleep 3
# do a request after TTL to invalidate the cache
res_tmp=$(fetch_time "${CACHED_ENDPOINT}")
sleep 1
res2=$(fetch_time "${CACHED_ENDPOINT}")
if [ "${res1}" -eq "${res2}" ]; then
  error "caching ttl is not working"
fi
if [ "${res1}" -ge "${res2}" ]; then
  error "timestamp is not increasing"
fi

info "Check if it can cache POST request…"
# invalidate cache if needed
res_tmp=$(fetch_time_post "${CACHED_ENDPOINT}")
res1=$(fetch_time_post "${CACHED_ENDPOINT}")
res2=$(fetch_time_post "${CACHED_ENDPOINT}")
if [ "${res1}" -ne "${res2}" ]; then
  error "timestamp is changing => page is not cached"
fi

info "Check if TTL is working as expected on POST request (assuming CACHE_TTL=2s)…"
sleep 3
# do a request after TTL to invalidate the cache
res_tmp=$(fetch_time_post "${CACHED_ENDPOINT}")
sleep 1
res2=$(fetch_time_post "${CACHED_ENDPOINT}")
if [ "${res1}" -eq "${res2}" ]; then
  error "caching ttl is not working"
fi
if [ "${res1}" -ge "${res2}" ]; then
  error "timestamp is not increasing"
fi

info "Check if it can cache authenticated page…"
# invalidate cache if needed
res_tmp=$(fetch_auth_time "${CACHED_ENDPOINT}" "super-secret-token")
res1=$(fetch_auth_time "${CACHED_ENDPOINT}" "super-secret-token")
res2=$(fetch_auth_time "${CACHED_ENDPOINT}" "super-secret-token")
if [ "${res1}" -ne "${res2}" ]; then
  error "timestamp is changing => page is not cached"
fi

info "Check if TTL is working as expected on authenticated page (assuming CACHE_TTL=2s)…"
sleep 3
# do a request after TTL to invalidate the cache
res_tmp=$(fetch_auth_time "${CACHED_ENDPOINT}" "super-secret-token")
sleep 1
res2=$(fetch_auth_time "${CACHED_ENDPOINT}" "super-secret-token")
if [ "${res1}" -eq "${res2}" ]; then
  error "caching ttl is not working"
fi
if [ "${res1}" -ge "${res2}" ]; then
  error "timestamp is not increasing"
fi

info "Check if it can cache authenticated POST request…"
# invalidate cache if needed
res_tmp=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token")
res_tmp=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token-2")
res1=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token")
res2=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token")
res3=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token-2")
if [ "${res1}" -ne "${res2}" ]; then
  error "timestamp is changing => page is not cached"
fi
if [ "${res1}" -eq "${res3}" ]; then
  error "cache does not consider authorization header"
fi

info "Check if TTL is working as expected on authenticated POST request (assuming CACHE_TTL=2s)…"
sleep 3
# do a request after TTL to invalidate the cache
res_tmp=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token")
res_tmp=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token-2")
sleep 1
res2=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token")
res4=$(fetch_auth_time_post "${CACHED_ENDPOINT}" "super-secret-token-2")
if [ "${res1}" -eq "${res2}" ]; then
  error "caching ttl is not working"
fi
if [ "${res3}" -eq "${res4}" ]; then
  error "caching ttl is not working"
fi
if [ "${res1}" -ge "${res2}" ]; then
  error "timestamp is not increasing"
fi
if [ "${res3}" -ge "${res4}" ]; then
  error "timestamp is not increasing"
fi


# If we are at this point, no test failed

info "All tests passed :)"
