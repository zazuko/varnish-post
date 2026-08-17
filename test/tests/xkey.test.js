import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { fetchTime, purge, request, uniquePath } from "../helpers/varnish.js";

/** The backend echoes everything after `/x-header/` back as the `xkey` header. */
const tagged = (tag) => `/x-header/${tag}`;

const body = { method: "POST", json: { foo: "bar" } };

describe("xkey tag invalidation", () => {
  it("tags a response with the xkey header sent by the backend", async () => {
    const tag = uniquePath("tag").slice(1);

    const { headers } = await request(tagged(tag));

    assert.equal(headers.get("xkey"), tag);
  });

  it("invalidates every entry carrying the purged tag, and nothing else", async () => {
    const tag = uniquePath("tag").slice(1);
    const otherTag = uniquePath("tag").slice(1);

    const taggedBefore = await fetchTime(tagged(tag), body);
    const otherBefore = await fetchTime(tagged(otherTag), body);

    const { status } = await purge("/", { headers: { xkey: tag } });
    assert.equal(status, 200);

    const taggedAfter = await fetchTime(tagged(tag), body);
    const otherAfter = await fetchTime(tagged(otherTag), body);

    assert.notEqual(taggedAfter, taggedBefore, "the tagged entry survived the purge");
    assert.equal(otherAfter, otherBefore, "an entry with a different tag was purged as well");
  });

  it("invalidates every cached variant carrying the tag", async () => {
    // A tag purge matches the xkey index rather than the cache key, so unlike a
    // URL PURGE it reaches the GET entry, every POST body and every
    // Authorization variant at once.
    const tag = uniquePath("tag").slice(1);
    const path = tagged(tag);
    const bar = { method: "POST", json: { foo: "bar" } };
    const foobar = { method: "POST", json: { foo: "foobar" } };
    const authenticated = { headers: { Authorization: "Basic super-secret-token" } };

    const before = {
      get: await fetchTime(path),
      bar: await fetchTime(path, bar),
      foobar: await fetchTime(path, foobar),
      authenticated: await fetchTime(path, authenticated),
    };

    await purge("/", { headers: { xkey: tag } });

    assert.notEqual(await fetchTime(path), before.get, "the GET variant survived");
    assert.notEqual(await fetchTime(path, bar), before.bar, "the POST {foo:bar} variant survived");
    assert.notEqual(
      await fetchTime(path, foobar),
      before.foobar,
      "the POST {foo:foobar} variant survived",
    );
    assert.notEqual(
      await fetchTime(path, authenticated),
      before.authenticated,
      "the authenticated variant survived",
    );
  });

  it("does not tag routes that only look like the xkey route", async () => {
    // `/x-header-<tag>` hits the catch-all `/:name` route, so it never receives
    // an xkey header and a tag purge must leave it alone.
    const tag = uniquePath("tag").slice(1);

    const lookalike = `/x-header-${tag}`;
    const before = await fetchTime(lookalike, body);

    await purge("/", { headers: { xkey: tag } });

    const after = await fetchTime(lookalike, body);

    assert.equal(after, before, "an untagged lookalike route was purged");
  });

  it("treats an encoded tag and its raw form as the same tag", async () => {
    // The backend URL-decodes the tag, so both spellings end up tagged alike.
    const raw = "http://example.com/custom/path";
    const encoded = "http%3A%2F%2Fexample.com%2Fcustom%2Fpath";

    const rawBefore = await fetchTime(tagged(raw), body);
    const encodedBefore = await fetchTime(tagged(encoded), body);

    // Distinct URLs, so they are distinct cache entries sharing one tag.
    assert.notEqual(encodedBefore, rawBefore, "the two spellings shared a cache entry");

    await purge("/", { headers: { xkey: raw } });

    const rawAfter = await fetchTime(tagged(raw), body);
    const encodedAfter = await fetchTime(tagged(encoded), body);

    assert.notEqual(rawAfter, rawBefore, "the raw entry survived the purge");
    assert.notEqual(encodedAfter, encodedBefore, "the encoded entry survived the purge");
  });
});
