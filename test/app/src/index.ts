import fastify from "fastify";
import fastifyFormbody from "@fastify/formbody";

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
server.all<{
  Params: {
    headerValue: string;
  };
}>("/x-header/:headerValue", async (request, reply) => {
  return reply.header("xkey", request.params.headerValue).send({
    hello: "xkey header",
    time: Date.now(),
    value: request.params.headerValue,
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
