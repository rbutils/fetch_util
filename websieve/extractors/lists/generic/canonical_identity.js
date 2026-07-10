  function listCanonicalKey(url) {
    if (!url) return "";

    try {
      var parsed = new URL(url, location.href);
      var key = parsed.origin + parsed.pathname + parsed.search;
      key = key.replace(/([?&])(?:utm_[^&=]+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)=[^&]*&?/gi, "$1");
      return key.replace("?&", "?").replace(/[?&]$/, "");
    } catch (_error) {
      return url.split("#")[0];
    }
  }
