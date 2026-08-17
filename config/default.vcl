vcl 4.1;

import std;
import bodyaccess;
import xkey;

acl purge {
  $PURGE_ACL;
}

# Backend server that should be cached
backend default {
  .host = "$BACKEND_HOST";
  .port = "$BACKEND_PORT";
  .first_byte_timeout = $BACKEND_FIRST_BYTE_TIMEOUT;
}

# Remove cookies and other non-cache-friendly headers from the backend response
sub vcl_backend_response {
  if (beresp.http.Cache-Control) {
    unset beresp.http.Cache-Control;
  }

  if (beresp.http.Set-Cookie) {
    unset beresp.http.Set-Cookie;
  }

  set beresp.ttl = $CACHE_TTL;

  # Decide not to cache error responses
  if ($DISABLE_ERROR_CACHING && beresp.status >= 400) {
    set beresp.ttl = $DISABLE_ERROR_CACHING_TTL;
    set beresp.uncacheable = true;
    return (deliver);
  }

  # Tag every cached object with its own URL, using the legacy header the xkey
  # vmod also indexes. This is what lets a PURGE invalidate all of a URL's
  # entries at once: the request body, Authorization and Accept are part of the
  # cache key, so one URL can hold many objects that a single lookup cannot
  # reach. Kept separate from the "xkey" header so the tags the backend sends
  # are left untouched.
  if (beresp.http.X-HashTwo) {
    set beresp.http.X-HashTwo = beresp.http.X-HashTwo + " " + bereq.url;
  } else {
    set beresp.http.X-HashTwo = bereq.url;
  }
}

# Handles incoming requests and removes incoming cookies
sub vcl_recv {
  unset req.http.X-Body-Len;
  unset req.http.cookie;

  # Handle PURGE requests
  if (req.method == "PURGE") {
    if (!client.ip ~ purge) {
      return (synth(405, "Method Not Allowed"));
    }
    # An explicit tag invalidates every entry carrying it.
    if (req.http.xkey) {
      set req.http.n-gone = xkey.purge(req.http.xkey);
      return (synth(200, "Invalidated " + req.http.n-gone + " objects"));
    } else {
      # Otherwise invalidate every cached variant of this URL. Objects are
      # tagged with their URL in vcl_backend_response, so purging that tag drops
      # the GET entry together with every request body, Authorization and Accept
      # variant. A plain `return (purge)` would only reach the single entry
      # hashing identically to this request.
      set req.http.n-gone = xkey.purge(req.url);
      return (synth(200, "Invalidated " + req.http.n-gone + " objects"));
    }
  }

  # Caching POST requests by caching the request body
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

# Alter the hashing method to include POST bodies
# See: https://docs.varnish-software.com/tutorials/caching-post-requests/#step-3-change-the-hashing-function
sub vcl_hash {
  hash_data(req.http.Authorization);
  hash_data(req.http.Accept);
  hash_data(req.url);

  if (req.http.X-Body-Len) {
    bodyaccess.hash_req_body();
  } else {
    hash_data("");
  }

  return (lookup);
}

# Adjust the request method in the backend fetch phase
# See: https://docs.varnish-software.com/tutorials/caching-post-requests/#step-4-make-sure-the-backend-gets-a-post-request
sub vcl_backend_fetch {
  if (bereq.http.X-Body-Len) {
    set bereq.method = "POST";
  }

  return (fetch);
}

# Indicate whether the response was served from cache or not
# See: https://happyculture.coop/blog/varnish-4-comment-savoir-si-votre-page-vient-du-cache
sub vcl_deliver {
  if (resp.http.X-Varnish ~ "[0-9]+ +[0-9]+") {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }

  # Internal cache tag, of no use to clients. The cached object keeps it, so
  # invalidation is unaffected.
  unset resp.http.X-HashTwo;

  return (deliver);
}
