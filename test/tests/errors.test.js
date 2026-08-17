import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { fetchTime, request, uniquePath } from "../helpers/varnish.js";

/**
 * The backend exposes errors as `/error/:code`, so uniqueness has to ride in
 * the query string -- an extra path segment would not match the route. Varnish
 * hashes the full URL, so this still yields a private cache entry per test.
 */
const errorPath = (code) => `/error/${code}?case=${uniquePath("err").slice(1)}`;

describe("error responses", () => {
  it("passes the backend status through", async () => {
    const { status } = await request(errorPath(503));

    assert.equal(status, 503);
  });

  it("does not cache error responses", async () => {
    // DISABLE_ERROR_CACHING is on by default, so each request has to reach the
    // backend again and therefore carry a new timestamp.
    const path = errorPath(500);

    const first = await fetchTime(path);
    const second = await fetchTime(path);

    assert.notEqual(second, first, "an error response was served from cache");
    assert.ok(second > first, `expected ${second} to be later than ${first}`);
  });
});
