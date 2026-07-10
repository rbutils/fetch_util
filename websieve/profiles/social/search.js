  function pinterestSearchContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)pinterest\.com$/) && !/pinterest/i.test(signature)) return null;
    if (!/^\/search\//.test(location.pathname) && !queryParam("q") && !/showing more search results for/i.test(document.body && document.body.textContent)) return null;

    var query = normalizeText(queryParam("q"));
    var seen = {};
    var items = [];

    document.querySelectorAll("a[href*='/pin/']").forEach(function(link) {
      var url = absoluteUrl(link.getAttribute("href"));
      var text = normalizeText(link.getAttribute("aria-label") || link.textContent);
      if (!text) {
        var img = link.querySelector("img[alt]");
        text = normalizeText(img && img.getAttribute("alt"));
      }

      if (!url || !text || text.length < 12 || seen[url]) return;
      if (/^(log in|sign up|explore|search|filters|you are signed out)$/i.test(text)) return;

      seen[url] = true;
      items.push({ text: text, url: url });
    });

    if (items.length >= 4) {
      return listContentResult({
        title: query ? "Pinterest results for " + query : (metadata.title || document.title),
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || "Pinterest",
        items: items
      });
    }

    if (!metadata.excerpt) return null;

    return articleContentFromParts({
      title: query ? "Pinterest results for " + query : (metadata.title || document.title),
      description: metadata.excerpt,
      details: ["Access: Pinterest signed-out shell"],
      siteName: metadata.siteName || "Pinterest",
      contentType: "article"
    });
  }

  function registerPinterestSearchProfile() {
    registerHostAwareProfile(true, pinterestSearchContent);
  }
