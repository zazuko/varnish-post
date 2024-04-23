FROM docker.io/library/node:20-alpine

WORKDIR /app

# Install tini to handle signals
RUN apk add --no-cache tini

# Configure server listening
ENV SERVER_PORT="8080"
ENV SERVER_HOST="::"

# Build the app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# App is exposed on the specified port
EXPOSE "${SERVER_PORT}"

# Run as a non-root user
USER 1000:1000

CMD [ "tini", "--", "node", "dist/index.js" ]
