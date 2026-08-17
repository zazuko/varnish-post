import assert from "node:assert/strict";

const requiredEnv = (name: string): string => {
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
/** Prometheus exporter exposed by the Varnish container. */
export const METRICS_URL = requiredEnv("METRICS_URL");

/** Matches CACHE_TTL in compose.yaml. */
export const CACHE_TTL_MS = 2000;

export const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

let requestCounter = 0;

/**
 * Build a path that no other test uses.
 *
 * Test files run in parallel against one shared Varnish instance, so each case
 * needs its own cache entry to stay independent.
 */
export const uniquePath = (prefix = "case"): string => {
  requestCounter += 1;
  return `/${prefix}-${process.pid}-${requestCounter}`;
};

export interface RequestOptions {
  method?: string;
  /** Sent as a JSON body, with the matching Content-Type. */
  json?: unknown;
  headers?: Record<string, string>;
  /** Defaults to Varnish; pass BACKEND_URL to bypass the cache. */
  target?: string;
}

export interface HttpResponse {
  status: number;
  headers: Headers;
  text: string;
}

/**
 * Send a request to Varnish.
 *
 * The path is concatenated rather than resolved through `new URL()` so that
 * exotic paths (encoded characters, embedded URLs) reach Varnish untouched.
 */
export const request = async (
  path: string,
  { method = "GET", json, headers = {}, target }: RequestOptions = {},
): Promise<HttpResponse> => {
  const base = target ?? VARNISH_URL;
  const requestHeaders: Record<string, string> = { ...headers };
  const init: RequestInit = { method, headers: requestHeaders };

  if (json !== undefined) {
    init.body = JSON.stringify(json);
    requestHeaders["Content-Type"] = "application/json";
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
export const fetchTime = async (path: string, options: RequestOptions = {}): Promise<number> => {
  const { status, text } = await request(path, options);
  const method = options.method ?? "GET";

  let payload: { time?: unknown };
  try {
    payload = JSON.parse(text) as { time?: unknown };
  } catch {
    throw new Error(
      `Expected JSON from ${method} ${path} (HTTP ${status}) but got: ${text.slice(0, 200)}`,
    );
  }

  assert.ok(
    typeof payload.time === "number",
    `Expected a numeric "time" from ${method} ${path} (HTTP ${status}), got ${JSON.stringify(payload.time)}`,
  );

  return payload.time;
};

export const purge = (
  path: string,
  { headers = {}, json }: Pick<RequestOptions, "headers" | "json"> = {},
): Promise<HttpResponse> => request(path, { method: "PURGE", headers, json });

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
export const refreshAfterTtl = async (
  staleTime: number,
  path: string,
  options: RequestOptions = {},
  { graceMs = 1000 }: { graceMs?: number } = {},
): Promise<number> => {
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
