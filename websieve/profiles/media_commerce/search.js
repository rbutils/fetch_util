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

  function registerEbaySearchProfile() {
    registerHostAwareProfile(true, ebaySearchContent);
  }
