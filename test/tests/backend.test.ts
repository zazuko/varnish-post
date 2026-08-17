import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { BACKEND_URL, fetchTime, uniquePath } from "../helpers/varnish.ts";

describe("test backend", () => {
  it("stamps every response with an increasing timestamp", async () => {
    const path = uniquePath("backend");

    const first = await fetchTime(path, { target: BACKEND_URL });
    const second = await fetchTime(path, { target: BACKEND_URL });

    assert.notEqual(first, second, "backend served an identical timestamp twice");
    assert.ok(second > first, `expected ${second} to be later than ${first}`);
  });
});
