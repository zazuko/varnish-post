import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { fetchTime, refreshAfterTtl, uniquePath } from "../helpers/varnish.js";

const AUTH = { Authorization: "Basic super-secret-token" };
const OTHER_AUTH = { Authorization: "Basic super-secret-token-2" };

describe("caching", () => {
  it("caches a GET request", async () => {
    const path = uniquePath("get");

    const first = await fetchTime(path);
    const second = await fetchTime(path);

    assert.equal(second, first, "GET response was not served from cache");
  });

  it("re-fetches a GET request once the TTL expired", async () => {
    const path = uniquePath("get-ttl");

    const cached = await fetchTime(path);
    const refreshed = await refreshAfterTtl(cached, path);

    assert.ok(refreshed > cached, `expected ${refreshed} to be later than ${cached}`);
  });

  it("caches a POST request", async () => {
    const path = uniquePath("post");
    const options = { method: "POST", json: { foo: "bar" } };

    const first = await fetchTime(path, options);
    const second = await fetchTime(path, options);

    assert.equal(second, first, "POST response was not served from cache");
  });

  it("caches POST requests with different bodies separately", async () => {
    const path = uniquePath("post-body");

    const bar = await fetchTime(path, { method: "POST", json: { foo: "bar" } });
    const baz = await fetchTime(path, { method: "POST", json: { foo: "baz" } });

    assert.notEqual(baz, bar, "a different POST body reused the same cache entry");
  });

  it("re-fetches a POST request once the TTL expired", async () => {
    const path = uniquePath("post-ttl");
    const options = { method: "POST", json: { foo: "bar" } };

    const cached = await fetchTime(path, options);
    const refreshed = await refreshAfterTtl(cached, path, options);

    assert.ok(refreshed > cached, `expected ${refreshed} to be later than ${cached}`);
  });

  it("caches an authenticated GET request per Authorization header", async () => {
    const path = uniquePath("auth-get");

    const first = await fetchTime(path, { headers: AUTH });
    const second = await fetchTime(path, { headers: AUTH });
    const other = await fetchTime(path, { headers: OTHER_AUTH });

    assert.equal(second, first, "authenticated response was not served from cache");
    assert.notEqual(other, first, "a different Authorization header reused the same cache entry");
  });

  it("re-fetches an authenticated GET request once the TTL expired", async () => {
    const path = uniquePath("auth-get-ttl");
    const options = { headers: AUTH };

    const cached = await fetchTime(path, options);
    const refreshed = await refreshAfterTtl(cached, path, options);

    assert.ok(refreshed > cached, `expected ${refreshed} to be later than ${cached}`);
  });

  it("caches an authenticated POST request per Authorization header", async () => {
    const path = uniquePath("auth-post");
    const body = { foo: "bar" };

    const first = await fetchTime(path, { method: "POST", json: body, headers: AUTH });
    const second = await fetchTime(path, { method: "POST", json: body, headers: AUTH });
    const other = await fetchTime(path, { method: "POST", json: body, headers: OTHER_AUTH });

    assert.equal(second, first, "authenticated POST response was not served from cache");
    assert.notEqual(other, first, "a different Authorization header reused the same cache entry");
  });
});
