---
"varnish-post": minor
---

It is now possible to configure purge ACL, by setting the `PURGE_ACL` to a relevant hostname or IP CIDR.

By default, the `PURGE_ACL` is set to `localhost`.
This means that only requests coming from the same host as the Varnish container will be able to purge the cache.

You can set the `PURGE_ACL` to `0.0.0.0/0` to allow all hosts to purge the cache for example, or a more specific IP CIDR.
