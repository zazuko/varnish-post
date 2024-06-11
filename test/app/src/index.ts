import fastify from "fastify";
import fastifyFormbody from "@fastify/formbody";

/**
 * Cleanup header value.
 * Returns default value if the header value is not a string or is empty or too long (more than 256 characters long).
 *
 * @param headerValue Value of the header
 * @param defaultValue Default value of the header
 * @returns Cleaned up header value
 */
const cleanupHeaderValue = (
  headerValue: string,
  defaultValue: string
): string => {
  if (typeof headerValue !== "string") {
    return defaultValue;
  }

  // Split, remove all lines except the first one (can be CRLF, LF or CR), trim, and return
  const newValue = headerValue.split(/\r\n|\r|\n/)[0].trim();
  if (newValue.length === 0) {
    return defaultValue;
  }
  if (newValue.length > 256) {
    return defaultValue;
  }
  return newValue;
};

// Fetch values from environment variables
const port = process.env.SERVER_PORT || 8080;
const host = process.env.SERVER_HOST || "::";

// Init Fastify
const server = fastify({
  logger: true,
});

server.register(fastifyFormbody);

// Default route
server.all("/", async () => ({
  hello: "world",
  time: Date.now(),
}));

// Check particular error code
server.all<{
  Params: {
    code: number;
  };
}>("/error/:code", async (request, reply) => {
  reply.code(request.params.code).send({
    hello: "error",
    time: Date.now(),
    code: request.params.code,
  });
});

// Return a specific xkey header
server.all("/x-header/*", async (request, reply) => {
  const path =
    request.raw.url?.split("?")[0].split("/").slice(2).join("/") || "";
  const xkeyValue = cleanupHeaderValue(path, "default");

  return reply.header("xkey", xkeyValue).send({
    hello: "xkey header",
    time: Date.now(),
    value: xkeyValue,
  });
});

// Say hello to someone
server.all<{
  Params: {
    name: string;
  };
}>("/:name", async (request) => ({
  hello: request.params.name,
  time: Date.now(),
}));

// Start listening on specified host:port
(async () => {
  try {
    await server.listen({
      port: parseInt(`${port}`, 10),
      host,
    });
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
})();
