#!/bin/sh

# generate configuration file
envsubst \
  < /templates/default.vcl \
  > /etc/varnish/default.vcl

# run base image entrypoint
/usr/local/bin/docker-varnish-entrypoint "$@"
