---
"varnish-post": minor
---

A `PURGE` request now invalidates every cache entry of the target URL.

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
