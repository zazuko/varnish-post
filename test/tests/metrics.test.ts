import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { fetchTime, METRICS_URL, sleep, uniquePath } from "../helpers/varnish.ts";

const scrape = async (): Promise<string> => {
  const response = await fetch(`${METRICS_URL}/metrics`);

  assert.equal(response.status, 200, "the Prometheus exporter did not answer");

  return response.text();
};

/** Read a single unlabelled counter out of a Prometheus exposition payload. */
const counter = (payload: string, name: string): number => {
  const match = new RegExp(`^${name}\\s+(\\S+)$`, "m").exec(payload);

  assert.ok(match?.[1], `no "${name}" metric in the exporter output`);

  const value = Number(match[1]);
  assert.ok(Number.isFinite(value), `"${name}" is not a number: ${match[1]}`);

  return value;
};

describe("prometheus exporter", () => {
  it("serves metrics in the Prometheus exposition format", async () => {
    const payload = await scrape();

    assert.match(payload, /^# HELP varnish_/m, "no HELP lines for varnish metrics");
    assert.match(payload, /^# TYPE varnish_/m, "no TYPE lines for varnish metrics");
  });

  it("reports Varnish and its backend as up", async () => {
    const payload = await scrape();

    assert.equal(counter(payload, "varnish_up"), 1, "the exporter cannot reach Varnish");
    assert.match(payload, /^varnish_backend_up\{[^}]*\} 1$/m, "the backend is reported as down");
  });

  it("counts traffic flowing through the cache", async () => {
    // Worker threads accumulate their statistics and only publish them once the
    // lock is free, or after thread_stats_rate jobs (10 by default). The
    // exported counter therefore lags the requests that caused it, so keep
    // driving traffic until the published value catches up instead of assuming
    // a couple of requests are enough to move it.
    const before = counter(await scrape(), "varnish_main_client_req");
    const path = uniquePath("metrics");
    const deadline = Date.now() + 20_000;

    let after = before;

    while (Date.now() < deadline) {
      await fetchTime(path);

      after = counter(await scrape(), "varnish_main_client_req");
      if (after > before) {
        break;
      }

      await sleep(100);
    }

    assert.ok(after > before, `expected the request counter to grow, got ${before} then ${after}`);
  });

  it("exposes the cache hit counters used for hit-rate dashboards", async () => {
    const payload = await scrape();

    for (const name of ["varnish_main_cache_hit", "varnish_main_cache_miss"]) {
      assert.ok(Number.isFinite(counter(payload, name)), `"${name}" is missing`);
    }
  });
});
