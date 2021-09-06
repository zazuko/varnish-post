vcl 4.1;

import std;
import bodyaccess;

# this is the backend that should be cached
backend default {
  .host = "$BACKEND_HOST";
  .port = "$BACKEND_PORT";
  .first_byte_timeout = $BACKEND_FIRST_BYTE_TIMEOUT;
}

# remove cookies from response
sub vcl_backend_response {
  if (beresp.http.Cache-Control) {
    unset beresp.http.Cache-Control;
  }

  if (beresp.http.Set-Cookie) {
    unset beresp.http.Set-Cookie;
  }

  set beresp.ttl = $CACHE_TTL;
}

# remove incoming cookies and allow caching POST requests
sub vcl_recv {
  unset req.http.X-Body-Len;
  unset req.http.cookie;

  if (req.method == "POST") {
    std.cache_req_body($BODY_SIZE);
    set req.http.X-Body-Len = bodyaccess.len_req_body();
    if (req.http.X-Body-Len == "-1") {
      return (pass);
    }
    return (hash);
  }

  if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
  }

  return (hash);
}

# https://docs.varnish-software.com/tutorials/caching-post-requests/#step-3-change-the-hashing-function
sub vcl_hash {
  hash_data(req.http.Authorization);
  hash_data(req.url);

  # to cache POST and PUT requests
  if (req.http.X-Body-Len) {
    bodyaccess.hash_req_body();
  } else {
    hash_data("");
  }

  return (lookup);
}

# https://docs.varnish-software.com/tutorials/caching-post-requests/#step-4-make-sure-the-backend-gets-a-post-request
sub vcl_backend_fetch {
  if (bereq.http.X-Body-Len) {
    set bereq.method = "POST";
  }
}

# add a header to see if it was a cache miss or a cache hit
sub vcl_deliver {
  # https://happyculture.coop/blog/varnish-4-comment-savoir-si-votre-page-vient-du-cache
  if (resp.http.X-Varnish ~ "[0-9]+ +[0-9]+") {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }
}
