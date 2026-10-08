  function wordpressRestDeclaredEndpoint() {
    var links = document.querySelectorAll("head link[rel~='alternate'][type='application/json'][href]");
    var endpoint = null;
    for (var i = 0; i < links.length; i += 1) {
      try {
        var url = new URL(links[i].getAttribute("href"), location.href);
        var routes = url.searchParams.getAll("rest_route");
        var match = routes.length === 1 ? routes[0].match(/^\/wp\/v2\/(?:posts|pages)\/([1-9]\d*)\/?$/) :
          url.pathname.match(/(?:^|\/)wp-json\/wp\/v2\/(?:posts|pages)\/([1-9]\d*)\/?$/);
        if (!match) continue;
        if (routes.length > 1 || !/^https?:$/.test(url.protocol) || url.origin !== location.origin ||
            url.username || url.password || url.hash) return null;
        if (endpoint && endpoint.url !== url.href) return null;
        endpoint = { url: url.href, postId: match[1] };
      } catch (_error) { return null; }
    }
    return endpoint;
  }

  function wordpressRestIdentityUrl(value) {
    try {
      var url = new URL(value, location.href);
      if (!/^https?:$/.test(url.protocol) || url.origin !== location.origin || url.username || url.password) return null;
      return url.origin + (url.pathname.replace(/\/+$/, "") || "/") + url.search;
    } catch (_error) { return null; }
  }

  function wordpressRestSourceIdentity(metadata) {
    if (metadata && String(metadata.isAccessibleForFree).toLowerCase() === "false") return null;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node) && !node.closest("nav, aside, footer, [role='banner'], [role='navigation']") &&
        normalizeText(node.textContent || "");
    });
    if (headings.length !== 1) return null;
    var owner = headings[0].closest("article, main, [role='main']") || document.body;
    var barriers = owner.querySelectorAll(PUBLIC_ARTICLE_PAYWALL_SELECTORS.join(", ") + ", input[type='password']");
    if (Array.from(barriers).some(function(node) { return !elementSubtreeHidden(node); })) return null;
    var canonicalLinks = Array.from(document.querySelectorAll("head link[rel~='canonical'][href]"));
    var identities = canonicalLinks.map(function(node) { return wordpressRestIdentityUrl(node.getAttribute("href")); });
    if (!identities.length) identities.push(wordpressRestIdentityUrl(location.href));
    if (!identities[0] || identities.some(function(value) { return value !== identities[0]; })) return null;
    return { url: identities[0], title: normalizeText(headings[0].textContent || "") };
  }

  function wordpressRestFetch(endpoint) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", endpoint.url, false);
      xhr.send(null);
      if (xhr.status < 200 || xhr.status >= 300 || xhr.responseURL !== endpoint.url || !xhr.responseText) return null;
      return JSON.parse(xhr.responseText);
    } catch (_error) { return null; }
  }

  function wordpressRestPayloadMatchesSource(payload, endpoint, identity) {
    if (!payload || Array.isArray(payload) || String(payload.id) !== endpoint.postId ||
        typeof payload.link !== "string" || !normalizeText(payload.link) || !payload.title || typeof payload.title.rendered !== "string" ||
        !payload.content || typeof payload.content.rendered !== "string" || payload.content.protected === true ||
        wordpressRestIdentityUrl(payload.link) !== identity.url) return false;
    var title = document.createElement("div");
    title.innerHTML = payload.title.rendered;
    return normalizeText(title.textContent || "") === identity.title;
  }

  function wordpressRestArticleBody(options, metadata) {
    if (!options.restFallback) return null;
    var endpoint = wordpressRestDeclaredEndpoint();
    var identity = wordpressRestSourceIdentity(metadata);
    if (!endpoint || !identity) return null;
    var payload = wordpressRestFetch(endpoint);
    if (!wordpressRestPayloadMatchesSource(payload, endpoint, identity)) return null;
    var root = document.createElement("div");
    root.innerHTML = payload.content.rendered;
    if (normalizeText(root.textContent || "").length < (options.minBodyTextLength || 0)) return null;
    return root;
  }
