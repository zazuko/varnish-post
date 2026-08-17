import assert from "node:assert/strict";

const requiredEnv = (name) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(
      `${name} is not set. Run the suite with "npm test" so the Docker stack is started first.`,
    );
  }

  return value;
};

export const BACKEND_URL = requiredEnv("BACKEND_URL");
export const VARNISH_URL = requiredEnv("VARNISH_URL");

/** Matches CACHE_TTL in compose.yaml. */
export const CACHE_TTL_MS = 2000;

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let requestCounter = 0;

/**
 * Build a path that no other test uses.
 *
 * Test files run in parallel against one shared Varnish instance, so each case
 * needs its own cache entry to stay independent.
 */
export const uniquePath = (prefix = "case") => {
  requestCounter += 1;
  return `/${prefix}-${process.pid}-${requestCounter}`;
};

/**
 * Send a request to Varnish.
 *
 * The path is concatenated rather than resolved through `new URL()` so that
 * exotic paths (encoded characters, embedded URLs) reach Varnish untouched.
 */
export const request = async (path, { method = "GET", json, headers = {}, target } = {}) => {
  const base = target ?? VARNISH_URL;
  const init = { method, headers: { ...headers } };

  if (json !== undefined) {
    init.body = JSON.stringify(json);
    init.headers["Content-Type"] = "application/json";
  }

  const response = await fetch(`${base}${path}`, init);

  return { status: response.status, headers: response.headers, text: await response.text() };
};

/**
 * Read the backend's `time` field.
 *
 * The backend stamps every response with `Date.now()`, so an unchanged value
 * means the response was served from cache and a changed value means it was
 * fetched again.
 */
export const fetchTime = async (path, options = {}) => {
  const { status, text } = await request(path, options);

  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    throw new Error(
      `Expected JSON from ${options.method ?? "GET"} ${path} (HTTP ${status}) but got: ${text.slice(0, 200)}`,
    );
  }

  assert.equal(
    typeof payload.time,
    "number",
    `Expected a numeric "time" from ${options.method ?? "GET"} ${path} (HTTP ${status}), got ${JSON.stringify(payload.time)}`,
  );

  return payload.time;
};

export const purge = (path, { headers = {}, json } = {}) =>
  request(path, { method: "PURGE", headers, json });

/**
 * Let a cache entry expire, then return the refreshed timestamp.
 *
 * Varnish keeps serving an expired object during its grace period while it
 * revalidates in the background, so the request that first hits the expired
 * entry still returns the stale timestamp and only *triggers* the refresh. The
 * request after it must already see the new object.
 *
 * The refresh is expected to land promptly, so the wait afterwards is short and
 * bounded on purpose: an entry still being served stale beyond it is a failure,
 * not something to keep polling through.
 */
export const refreshAfterTtl = async (staleTime, path, options = {}, { graceMs = 1000 } = {}) => {
  await sleep(CACHE_TTL_MS + 500);

  // Serves the stale object and kicks off the background revalidation.
  const trigger = await fetchTime(path, options);
  assert.equal(
    trigger,
    staleTime,
    `expected ${path} to still serve the stale object during its grace period`,
  );

  await sleep(graceMs);

  const refreshed = await fetchTime(path, options);
  assert.notEqual(
    refreshed,
    staleTime,
    `${path} was still served from cache ${graceMs}ms after the revalidation was triggered`,
  );

  return refreshed;
};
