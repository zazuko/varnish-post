FROM node:14-alpine

WORKDIR /app

# install tini to handle signals
RUN apk add --no-cache tini

# configure server listening
ENV SERVER_PORT="8080"
ENV SERVER_HOST="::"

# build the app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# app is exposed on the specified port
EXPOSE "${SERVER_PORT}"

# run as "nobody", a non-root user
USER 65534:65534

CMD [ "tini", "--", "node", "dist/index.js" ]
