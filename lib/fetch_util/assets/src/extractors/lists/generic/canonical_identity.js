  function listCanonicalKey(url) {
    if (!url) return "";

    try {
      var parsed = new URL(url, location.href);
      var query = [];

      parsed.searchParams.forEach(function(value, name) {
        if (/^(?:utm_[^=]+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name)) return;
        query.push(encodeURIComponent(name) + "=" + encodeURIComponent(value));
      });

      query = query.sort().join("&");
      return parsed.origin + parsed.pathname + (query ? "?" + query : "");
    } catch (_error) {
      return url.split("#")[0];
    }
  }
