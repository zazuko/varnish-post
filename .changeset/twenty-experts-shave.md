---
"varnish-post": minor
---

Add xkey support in order to support tag-based invalidation.

The backend can now send a `xkey` header with a value that will be used to tag the cache entry.
This tag can be used to invalidate the cache entry by sending a `PURGE` request with the `xkey` header set to the same value like this:

```sh
curl -sL -X PURGE -H 'xkey: TAG_VALUE' http://varnish-endpoint/
```

Doing this will remove all cache entries that have the same tag value.
