# varnish-post

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
