# Run tests

Integration tests for the Varnish image, written in TypeScript with the
[Node.js test runner](https://nodejs.org/api/test.html). They exercise a real
stack: the `varnish` service built from this repository, caching an origin
server that the test process runs itself.

You will need the following tools on your machine:

- `docker` (with the Compose plugin)
- Node.js 24 or later

Then run:

```sh
npm ci
npm test
```

Node runs the `.ts` files directly by stripping their types, so there is no
build step and no test-runner dependency. TypeScript itself is only used to
check the types, which is a separate command:

```sh
npm run typecheck
```

Because the types are erased rather than compiled, only syntax Node can strip is
allowed -- no enums, namespaces or parameter properties. `erasableSyntaxOnly` in
[`tsconfig.json`](./tsconfig.json) enforces that, so the type checker rejects
anything that would fail at runtime. Relative imports use the `.ts` extension,
which is what Node resolves.

## How it works

[`global-setup.ts`](./global-setup.ts) starts the origin server from
[`backend.ts`](./backend.ts) in the test process, builds and starts the Varnish
container once, waits for both to answer, and tears everything down when the run
finishes. Both listen on **dynamically allocated ports**, whose URLs reach the
tests through `BACKEND_URL` and `VARNISH_URL`, so the suite never collides with
anything else already listening on your machine.

Only Varnish runs in a container. The origin is plain `node:http` in-process, so
there is no second project to maintain and no image to build for it. Varnish
reaches it over the Docker host gateway, which is why [`compose.yaml`](./compose.yaml)
maps `host.docker.internal` and expects `BACKEND_PORT` to be provided — the
stack is not meant to be started by hand.

Because the backend stamps every response with an increasing timestamp, the
tests assert on that value: unchanged means the response came from Varnish's
cache, changed means it was fetched from the origin again. The stamp is forced
to increase strictly, since an in-process server can answer twice inside the
same millisecond.

## Layout

| Path                    | What it covers                                      |
| ----------------------- | --------------------------------------------------- |
| `tests/backend.test.ts` | the test backend itself                             |
| `tests/caching.test.ts` | GET/POST caching, TTL expiry, `Authorization` split |
| `tests/errors.test.ts`  | error responses are passed through and not cached   |
| `tests/purge.test.ts`   | `PURGE` invalidation                                |
| `tests/xkey.test.ts`    | `xkey` tag-based invalidation                       |
| `tests/metrics.test.ts` | the Prometheus exporter                             |
| `helpers/varnish.ts`    | request/assertion helpers shared by the tests       |
| `backend.ts`            | the origin server Varnish caches                    |

Each test allocates its own URL via `uniquePath()`, so cases stay independent
even though the files run in parallel against one shared Varnish instance.

## Grace periods

Varnish keeps serving an expired object during its grace period while it
revalidates in the background. The request that first hits an expired entry
therefore still returns the _old_ timestamp and only triggers the refresh; the
request after it must already see the new object.

Tests that assert on expiry use `refreshAfterTtl()`, which follows exactly that
sequence: wait past the TTL, send the request that triggers revalidation (and
assert it still serves the stale object), then assert the next request is fresh.
The wait after the trigger is short and bounded on purpose — an entry still
being served stale beyond it is a failure worth reporting, not something to keep
polling through.
