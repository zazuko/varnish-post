---
"varnish-post": minor
---

Upgrade the base image to Ubuntu 26.04, which brings Varnish 7.7.3 (up from
7.1.1) and varnish-modules 0.26.0.

The Prometheus exporter is now installed from Ubuntu's `prometheus-varnish-exporter`
package instead of being compiled from source, so the image no longer needs a Go
build stage. It is the same upstream version (1.6.1) and now receives distribution
security updates.
