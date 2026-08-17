import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

/**
 * The origin server that Varnish caches in front of.
 *
 * It runs in the test process rather than in a container, so there is no second
 * Node project and no image to build. Only node:http is used, since none of the
 * routes read the request body.
 */

let lastTime = 0;

/**
 * A strictly increasing wall-clock stamp.
 *
 * Tests tell a cached response from a fresh one by comparing this value, and an
 * in-process server easily answers twice within the same millisecond, so a bare
 * `Date.now()` would report two genuinely distinct responses as identical.
 */
const nextTime = (): number => {
  const now = Date.now();
  lastTime = now > lastTime ? now : lastTime + 1;
  return lastTime;
};

const MAX_TAG_LENGTH = 256;

/**
 * Sanitise a value taken from the URL before echoing it back in a header.
 *
 * Keeps the first line only and rejects anything empty or overlong, so a
 * crafted URL cannot inject extra headers into the response.
 */
const cleanupHeaderValue = (value: string, defaultValue: string): string => {
  const firstLine = value.split(/\r\n|\r|\n/)[0]?.trim() ?? "";

  if (firstLine.length === 0 || firstLine.length > MAX_TAG_LENGTH) {
    return defaultValue;
  }

  try {
    return decodeURIComponent(firstLine);
  } catch {
    return defaultValue;
  }
};

const respond = (
  response: ServerResponse,
  status: number,
  payload: Record<string, unknown>,
  headers: Record<string, string> = {},
): void => {
  response.writeHead(status, { "content-type": "application/json; charset=utf-8", ...headers });
  response.end(JSON.stringify(payload));
};

const XKEY_PREFIX = "/x-header/";

const handle = (request: IncomingMessage, response: ServerResponse): void => {
  // Nothing reads the body, but it still has to be drained so the connection
  // can be reused.
  request.resume();

  const path = (request.url ?? "/").split("?")[0] ?? "/";

  if (path === "/") {
    respond(response, 200, { hello: "world", time: nextTime() });
    return;
  }

  // Echoes the rest of the path back as an xkey tag, which is what lets the
  // tests exercise tag-based invalidation.
  if (path.startsWith(XKEY_PREFIX)) {
    const value = cleanupHeaderValue(path.slice(XKEY_PREFIX.length), "default");
    respond(response, 200, { hello: "xkey header", time: nextTime(), value }, { xkey: value });
    return;
  }

  // Returns an arbitrary status code, for the error-caching tests.
  const error = /^\/error\/([^/]+)$/.exec(path);
  if (error?.[1]) {
    const code = error[1];
    const status = Number(code);
    const valid = Number.isInteger(status) && status >= 100 && status <= 599;

    respond(response, valid ? status : 500, { hello: "error", time: nextTime(), code });
    return;
  }

  const named = /^\/([^/]+)$/.exec(path);
  if (named?.[1]) {
    respond(response, 200, { hello: named[1], time: nextTime() });
    return;
  }

  respond(response, 404, { hello: "not found", time: nextTime() });
};

export interface Backend {
  /** Loopback URL for the tests themselves. */
  url: string;
  /** Host port, handed to the Varnish container through the compose file. */
  port: number;
  close: () => Promise<void>;
}

export const startBackend = async (): Promise<Backend> => {
  const server = createServer(handle);

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    // Bound on every interface, because the Varnish container reaches this
    // through the Docker host gateway rather than over loopback.
    server.listen(0, "0.0.0.0", resolve);
  });

  const { port } = server.address() as AddressInfo;

  return {
    url: `http://127.0.0.1:${port}`,
    port,
    close: () =>
      new Promise<void>((resolve, reject) => {
        // Varnish holds keep-alive connections open, which would otherwise
        // delay the close until they time out.
        server.closeAllConnections();
        server.close((error) => (error ? reject(error) : resolve()));
      }),
  };
};
