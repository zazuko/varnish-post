import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { fetchTime, purge, uniquePath } from "../helpers/varnish.js";

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

  it(
    "invalidates every cached variant of the purged URL",
    {
      // Known gap, not a flaky test.
      //
      // The request body, Authorization and Accept are all part of the cache key
      // (see vcl_hash), so one URL holds many entries. `return (purge)` in
      // vcl_recv matches a single hash, so it only drops the variant whose key
      // equals the PURGE request's own -- every other variant stays cached.
      //
      // The body is the most visible case: vcl_recv handles PURGE before the
      // POST body is cached, so X-Body-Len is never set, vcl_hash takes its
      // empty-body branch, and a PURGE replaying a POST body invalidates the GET
      // entry rather than the POST entry it was aimed at.
      todo: "PURGE only drops the variant matching its own cache key (see vcl_recv/vcl_hash)",
    },
    async () => {
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
      assert.notEqual(
        await fetchTime(path, bar),
        before.bar,
        "the POST {foo:bar} variant survived",
      );
      assert.notEqual(
        await fetchTime(path, baz),
        before.baz,
        "the POST {foo:baz} variant survived",
      );
      assert.notEqual(
        await fetchTime(path, authenticated),
        before.authenticated,
        "the authenticated variant survived",
      );
    },
  );

  it("accepts a PURGE from a client inside the ACL", async () => {
    // PURGE_ACL is 0.0.0.0/0 in this stack, so the request is served rather
    // than answered with the 405 that vcl_recv returns for denied clients.
    const { status } = await purge(uniquePath("purge-acl"));

    assert.equal(status, 200);
  });
});
