import fastify from 'fastify';

// fetch values from environment variables
const port = process.env.SERVER_PORT || 8080;
const host = process.env.SERVER_HOST || '::';

// init fastify
const server = fastify({
  logger: true,
});

// default route
server.get('/', async () => ({
  hello: 'world',
  time: Date.now(),
}));

// say hello to someone
server.get<{
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
    await server.listen(port, host);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
})();
