#!/bin/sh

BACKEND_ENDPOINT="http://localhost:8080"
CACHED_ENDPOINT="http://localhost:8081"

# build and start the stack
docker compose build
docker compose up -d

# Some useful functions

# Display error message and exit
## $1: error message to display
error () {
  echo "ERROR: $1" >&2
  docker compose down
  exit 1
}

# Display information message
## $1: info message to display
info () {
  echo "INFO: $1"
}

# Wait that a specific HTTP endpoint is ready
## $1: HTTP endpoint to test
wait_http_endpoint() {
  RETRIES=30
  while true; do
    curl -sL "$1" 2>&1 >/dev/null
    if [ "$?" -eq 0 ]; then
      break
    fi

    RETRIES=$((RETRIES-1))
    if [ "${RETRIES}" -le 0 ]; then
      error "endpoint $1 is not ready"
    fi

    sleep 1
  done
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

info "Wait for backend application…"
wait_http_endpoint "${BACKEND_ENDPOINT}"

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

info "Wait for cached endpoint…"
wait_http_endpoint "${CACHED_ENDPOINT}"

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

info "Check if errors are not cached…"
sleep 3
# do a request after TTL to invalidate the cache
res_tmp=$(fetch_time "${CACHED_ENDPOINT}/error/500")
res1=$(fetch_time "${CACHED_ENDPOINT}/error/500")
sleep 1
res2=$(fetch_time "${CACHED_ENDPOINT}/error/500")
if [ "${res1}" -eq "${res2}" ]; then
  error "error was cached, which should not be the case"
fi
if [ "${res1}" -ge "${res2}" ]; then
  error "timestamp is not increasing"
fi

info "Check if we can purge a cache entry…"
sleep 3
# do a request after TTL to invalidate the cache
res_tmp=$(fetch_time "${CACHED_ENDPOINT}")
res1=$(fetch_time "${CACHED_ENDPOINT}")
res1_1=$(fetch_time "${CACHED_ENDPOINT}/cached")
res1_2=$(fetch_time "${CACHED_ENDPOINT}/purged")
sleep 1
curl -sL -X PURGE "${CACHED_ENDPOINT}" >/dev/null
curl -sL -X PURGE "${CACHED_ENDPOINT}/purged" >/dev/null
res2=$(fetch_time "${CACHED_ENDPOINT}")
res2_1=$(fetch_time "${CACHED_ENDPOINT}/cached")
res2_2=$(fetch_time "${CACHED_ENDPOINT}/purged")
if [ "${res1}" -eq "${res2}" ]; then
  error "cache was not purged"
fi
if [ "${res1_1}" -ne "${res2_1}" ]; then
  error "cache was purged"
fi
if [ "${res1_2}" -eq "${res2_2}" ]; then
  error "cache was not purged"
fi


# If we are at this point, no test failed
info "All tests passed :)"
docker compose down
exit 0
