# varnish-post

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
