import fastify from 'fastify';

// fetch values from environment variables
const port = process.env.SERVER_PORT || 8080;
const host = process.env.SERVER_HOST || '::';

// init fastify
const server = fastify({
  logger: true,
});

// default route
server.all('/', async () => ({
  hello: 'world',
  time: Date.now(),
}));

// check particular error code
server.all<{
  Params: {
    code: number;
  };
}>('/error/:code', async (request, reply) => {
  reply.code(request.params.code).send({
    hello: 'error',
    time: Date.now(),
    code: request.params.code,
  });
});

// say hello to someone
server.all<{
  Params: {
    name: string;
  };
}>('/:name', async (request) => ({
  hello: request.params.name,
  time: Date.now(),
}));

// start listening on specified host:port
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
