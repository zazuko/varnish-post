# Run tests

Integration tests for the Varnish image, written with the [Node.js test
runner](https://nodejs.org/api/test.html). They exercise a real stack: the
`varnish` service from this repository sitting in front of the small Fastify
backend in [`app/`](./app).

You will need the following tools on your machine:

- `docker` (with the Compose plugin)
- Node.js 24 or later

Then run:

```sh
npm test
```

There is nothing to install first: the tests only use Node built-ins.

## How it works

[`global-setup.js`](./global-setup.js) builds and starts the Compose stack once,
waits for both services to answer, and tears everything down when the run
finishes. It publishes the container ports on **dynamically allocated host
ports** and hands their URLs to the tests through `BACKEND_URL` and
`VARNISH_URL`, so the suite never collides with anything else already listening
on your machine.

Because the backend stamps every response with `Date.now()`, the tests assert on
that timestamp: an unchanged value means the response came from Varnish's cache,
and a changed value means it was fetched from the backend again.

## Layout

| Path                             | What it covers                                     |
| -------------------------------- | -------------------------------------------------- |
| `tests/backend.test.js`          | the test backend itself                            |
| `tests/caching.test.js`          | GET/POST caching, TTL expiry, `Authorization` split |
| `tests/errors.test.js`           | error responses are passed through and not cached  |
| `tests/purge.test.js`            | `PURGE` invalidation                               |
| `tests/xkey.test.js`             | `xkey` tag-based invalidation                      |
| `helpers/varnish.js`             | request/assertion helpers shared by the tests      |

Each test allocates its own URL via `uniquePath()`, so cases stay independent
even though the files run in parallel against one shared Varnish instance.

## Grace periods

Varnish keeps serving an expired object during its grace period while it
revalidates in the background. The request that first hits an expired entry
therefore still returns the *old* timestamp and only triggers the refresh; the
request after it must already see the new object.

Tests that assert on expiry use `refreshAfterTtl()`, which follows exactly that
sequence: wait past the TTL, send the request that triggers revalidation (and
assert it still serves the stale object), then assert the next request is fresh.
The wait after the trigger is short and bounded on purpose — an entry still
being served stale beyond it is a failure worth reporting, not something to keep
polling through.
