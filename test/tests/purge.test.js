import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { fetchTime, purge, request, uniquePath } from "../helpers/varnish.js";

const AUTH = { Authorization: "Basic super-secret-token" };

describe("PURGE", () => {
  it("invalidates only the purged URL", async () => {
    const purged = uniquePath("purge-target");
    const kept = uniquePath("purge-bystander");

    const purgedBefore = await fetchTime(purged);
    const keptBefore = await fetchTime(kept);

    await purge(purged);

    assert.notEqual(await fetchTime(purged), purgedBefore, "the purged entry survived");
    assert.equal(await fetchTime(kept), keptBefore, "an unrelated URL was purged as well");
  });

  it("invalidates every cached variant of the purged URL", async () => {
    // The request body, Authorization and Accept are all part of the cache key
    // (see vcl_hash), so one URL holds many entries. A PURGE has to drop them
    // all, not just the one matching the PURGE request's own key.
    const path = uniquePath("purge-variants");
    const bar = { method: "POST", json: { foo: "bar" } };
    const baz = { method: "POST", json: { foo: "baz" } };
    const authenticated = { headers: AUTH };

    const before = {
      get: await fetchTime(path),
      bar: await fetchTime(path, bar),
      baz: await fetchTime(path, baz),
      authenticated: await fetchTime(path, authenticated),
    };

    await purge(path);

    assert.notEqual(await fetchTime(path), before.get, "the GET variant survived");
    assert.notEqual(await fetchTime(path, bar), before.bar, "the POST {foo:bar} variant survived");
    assert.notEqual(await fetchTime(path, baz), before.baz, "the POST {foo:baz} variant survived");
    assert.notEqual(
      await fetchTime(path, authenticated),
      before.authenticated,
      "the authenticated variant survived",
    );
  });

  it("ignores the body of the PURGE request", async () => {
    // A PURGE is scoped by URL, so whatever body it carries is irrelevant.
    const path = uniquePath("purge-body-ignored");
    const post = { method: "POST", json: { foo: "bar" } };

    const getBefore = await fetchTime(path);
    const postBefore = await fetchTime(path, post);

    await purge(path, { json: { something: "unrelated" } });

    assert.notEqual(await fetchTime(path), getBefore, "the GET variant survived");
    assert.notEqual(await fetchTime(path, post), postBefore, "the POST variant survived");
  });

  it("does not leak the internal URL tag to clients", async () => {
    const { headers } = await request(uniquePath("purge-tag-hidden"));

    assert.equal(headers.get("x-hashtwo"), null, "the internal cache tag was delivered to clients");
  });

  it("accepts a PURGE from a client inside the ACL", async () => {
    // PURGE_ACL is 0.0.0.0/0 in this stack, so the request is served rather
    // than answered with the 405 that vcl_recv returns for denied clients.
    const { status } = await purge(uniquePath("purge-acl"));

    assert.equal(status, 200);
  });
});
