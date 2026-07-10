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

  function tikTokContent(metadata, pageText) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)tiktok\.com$/) && !/tiktok/i.test(signature)) return null;

    var page = normalizeText(pageText || "");
    var heading = firstText(["main h1", "h1"]);
    var subheading = firstText(["main h2", "h2"]);
    var pathTag = safeDecodeURI((location.pathname || "").replace(/^\/tag\//, "").split("/")[0] || "").replace(/[-_]+/g, " ");
    pathTag = normalizeText(pathTag);

    if (/^\/tag\//.test(location.pathname) || heading || subheading) {
      var title = heading || (pathTag ? "#" + pathTag : normalizeText(metadata.title || document.title));
      var description = metadata.excerpt;
      if (!description || /make your day/i.test(description)) description = "This TikTok page is only partially available, but the visible tag or page summary can still be extracted.";

      var details = [];
      if (subheading && subheading !== title) details.push(subheading);
      if (/drag the slider to fit the puzzle|log in/i.test(page)) details.push("Access notice: TikTok login or verification required");

      return articleContentFromParts({
        title: title,
        description: description,
        details: details,
        siteName: metadata.siteName || "TikTok",
        contentType: "article"
      });
    }

    if (!/drag the slider to fit the puzzle|slide to verify/i.test(page)) return null;

    return articleContentFromParts({
      title: normalizeText(metadata.title || document.title) || "TikTok verification required",
      description: metadata.excerpt || "This TikTok page is presenting a slider verification challenge before the original content is available.",
      details: ["Gate: slider verification"],
      siteName: metadata.siteName || "TikTok",
      contentType: "article"
    });
  }

  function ebaySearchContent(metadata, pageText) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)ebay\./) && !/ebay/i.test(signature)) return null;
    if (!/\/sch\//.test(location.pathname) && !queryParam("_nkw") && !/for sale\s*\|\s*ebay/i.test(signature)) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("a.s-item__link[href*='/itm/'], li.s-item a[href*='/itm/']").forEach(function(link) {
      var url = absoluteUrl(link.getAttribute("href"));
      var title = normalizeText(link.textContent || (link.querySelector("img[alt]") && link.querySelector("img[alt]").getAttribute("alt")));
      var container = link.closest("li.s-item, .srp-results li") || link.parentElement;
      var detail = searchItemDetail(container, title);

      if (!url || !title || title.length < 8 || seen[url]) return;
      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length >= 4) {
      return listContentResult({
        title: metadata.title || document.title,
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || "eBay",
        items: items
      });
    }

    if (!metadata.excerpt && !/cookie/i.test(pageText || "")) return null;

    return articleContentFromParts({
      title: metadata.title || document.title,
      description: metadata.excerpt || "This eBay page is showing a cookie or privacy prompt before full results are available.",
      details: ["Access notice: eBay cookie or privacy prompt"],
      siteName: metadata.siteName || "eBay",
      contentType: "article"
    });
  }

  function registerSocialSearchProfiles() {
    registerHostAwareProfile(true, pinterestSearchContent);
    registerHostAwareProfile(true, tikTokContent);
    registerHostAwareProfile(true, ebaySearchContent);
  }
