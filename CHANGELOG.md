# varnish-post

## 2.10.0

### Minor Changes

- 8465952: Upgrade the base image to Ubuntu 26.04, which brings Varnish 7.7.3 (up from
  7.1.1) and varnish-modules 0.26.0.
  
  The Prometheus exporter is now installed from Ubuntu's `prometheus-varnish-exporter`
  package instead of being compiled from source, so the image no longer needs a Go
  build stage. It is the same upstream version (1.6.1) and now receives distribution
  security updates.
  
  The entrypoint also got a few fixes:
  
  - Variable substitution in the configuration templates is now restricted to the
    documented configuration variables. It previously replaced anything that looked
    like a variable, so a configuration supplied through `CONFIG_FILE` could get
    `$HOME` rewritten to the container's home directory, and any unknown `$NAME`
    silently replaced by an empty string. **A custom configuration that relies on
    substituting its own environment variables is no longer substituted**; the
    template is left untouched and Varnish reports it as a configuration error.
  - Varnish is now started with `exec`, so it is the direct child of the init
    process and handles the signals that stop the container. The container now
    exits cleanly instead of reporting the exit code of a terminated process.
  - A missing `CONFIG_FILE` is reported with an explicit error listing the
    configuration files that were generated, instead of failing further down.
  - The Prometheus exporter now waits for Varnish to publish its statistics rather
    than for a fixed delay, which removes the error it used to log on startup.

## 2.9.0

### Minor Changes

- 28db80c: A `PURGE` request now invalidates every cache entry of the target URL.
  
  The request body, the `Authorization` header and the `Accept` header are all part
  of the cache key, so a single URL can hold several cache entries. `PURGE` matched
  that whole key and therefore only ever dropped one of them. Worse, since the body
  was not read for a `PURGE`, a `PURGE` replaying a cached POST body invalidated the
  `GET` entry of that URL rather than the POST entry it was aimed at.
  
  Cached objects are now tagged with their URL, and a `PURGE` invalidates that tag,
  so it drops the `GET` entry together with every request body, `Authorization` and
  `Accept` variant of the URL. The body of the `PURGE` request itself is ignored.
  
  Purging by an explicit `xkey` header is unchanged, and the `xkey` header sent by
  the backend is still delivered untouched: the URL tag rides on the `X-HashTwo`
  header that the xkey vmod also indexes, and is stripped before the response is
  delivered.

## 2.8.1

### Patch Changes

- 5924c4c: Upgrade various dependencies

## 2.8.0

### Minor Changes

- ce9e42c: Also hash the Accept header

## 2.7.0

### Minor Changes

- 513b918: Add support for `CUSTOM_ARGS`

## 2.6.0

### Minor Changes

- d5f1065: Upgrade Ubuntu to 24.04 for the base image

## 2.5.0

### Minor Changes

- 60aa54b: It is now possible to configure purge ACL, by setting the `PURGE_ACL` to a relevant hostname or IP CIDR.

  By default, the `PURGE_ACL` is set to `localhost`.
  This means that only requests coming from the same host as the Varnish container will be able to purge the cache.

  You can set the `PURGE_ACL` to `0.0.0.0/0` to allow all hosts to purge the cache for example, or a more specific IP CIDR.

## 2.4.0

### Minor Changes

- 3db843d: Enable Prometheus Exporter by setting `ENABLE_PROMETHEUS_EXPORTER` to `true`.

## 2.3.0

### Minor Changes

- 1b8342c: Add xkey support in order to support tag-based invalidation.

  The backend can now send a `xkey` header with a value that will be used to tag the cache entry.
  This tag can be used to invalidate the cache entry by sending a `PURGE` request with the `xkey` header set to the same value like this:

  ```sh
  curl -sL -X PURGE -H 'xkey: TAG_VALUE' http://varnish-endpoint/
  ```

  Doing this will remove all cache entries that have the same tag value.

## 2.2.0

### Minor Changes

- d247546: It is now possible to enable logs, by setting `ENABLE_LOGS` to `true`, which is now the default value.
  To disable them, just put any other value, like `false` for example.

## 2.1.0

### Minor Changes

- 0a37f35: Support `PURGE` method to purge the cache

## 2.0.0

### Major Changes

- 6f6ea26: Changed base from Alpine to Ubuntu.
