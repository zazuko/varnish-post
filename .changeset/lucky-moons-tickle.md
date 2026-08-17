---
"varnish-post": minor
---

Upgrade the base image to Ubuntu 26.04, which brings Varnish 7.7.3 (up from
7.1.1) and varnish-modules 0.26.0.

The Prometheus exporter is now installed from Ubuntu's `prometheus-varnish-exporter`
package instead of being compiled from source, so the image no longer needs a Go
build stage. It is the same upstream version (1.6.1) and now receives distribution
security updates.

The entrypoint also got a few fixes:

- Variable substitution in the configuration templates is now restricted to the
  documented configuration variables. It previously replaced anything that looked
  like a variable, so a configuration supplied through `CONFIG_FILE` could get
  `$HOME` rewritten to the container's home directory, and any unknown `$NAME`
  silently replaced by an empty string. **A custom configuration that relies on
  substituting its own environment variables is no longer substituted**; the
  template is left untouched and Varnish reports it as a configuration error.
- Varnish is now started with `exec`, so it is the direct child of the init
  process and handles the signals that stop the container. The container now
  exits cleanly instead of reporting the exit code of a terminated process.
- A missing `CONFIG_FILE` is reported with an explicit error listing the
  configuration files that were generated, instead of failing further down.
- The Prometheus exporter now waits for Varnish to publish its statistics rather
  than for a fixed delay, which removes the error it used to log on startup.
