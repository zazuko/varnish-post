# Varnish POST

> This Docker image let you cache GET and POST requests.

For POST requests, it will not cache requests with no body or with an empty body.

## Docker image

You can pull the Docker image using:

```sh
docker pull ghcr.io/zazuko/varnish-post
```

It is listening on the 80 port.

## Configuration

You can use following environment variables for configuration:

- `BACKEND_HOST`: host of the backend to cache (default: `localhost`)
- `BACKEND_PORT`: port of the backend to cache (default: `3000`)
- `VARNISH_SIZE`: size of the cache in the RAM (default: `100M`)
- `BACKEND_FIRST_BYTE_TIMEOUT`: first byte timeout (default: `60s`)
- `CACHE_TTL`: time to cache the request (default: `3600s`)
- `BODY_SIZE`: maximum size for the body ; if it exceeds this value, it will not be cached (default: `2048KB`)
- `DISABLE_ERROR_CACHING`: disable the caching of errors (default: `true`)
- `DISABLE_ERROR_CACHING_TTL`: time where requests should be directly sent to the backend after an error occured (default: `30s`)
- `CONFIG_FILE`: the name of the configuration file to use (default: `default.vcl`)
- `ENABLE_LOGS`: enable logs (default: `true`)
- `ENABLE_PROMETHEUS_EXPORTER`: enable the Prometheus exporter if set to `true` (default: `false`).
  If enabled, the exporter will be available on the 9131 port.

## Cache invalidation

You can invalidate the cache entry by sending the same request with the `PURGE` method.

If your backend is sending a `xkey` header, if you send a `PURGE` request with the same `xkey` header, it will invalidate all cache entries with the same tag.
