  function sozcuContent(metadata) {
    if (!hostMatches(/(^|\.)sozcu\.com\.tr$/)) return null;

    return sozcuHomepageContent(metadata);
  }

  function sozcuHomepageContent(metadata) {
    if (!homepageRootPath()) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll(".breaking-news a[href], .news-card a[href]").forEach(function(link) {
      if (items.length >= 18) return;
      if (link.closest(".bik-ilan, .currency, .authorSwiper, header, nav, footer, aside, form")) return;

      var href = link.getAttribute("href") || "";
      var url = absoluteUrl(href);
      if (!url || !/^https?:\/\/(?:www\.)?sozcu\.com\.tr\//i.test(url) || seen[url]) return;
      if (!/-p\d+(?:$|[?#])/i.test(url)) return;

      var title = searchItemTitle(link);
      if (!title || title.length < 18 || title.length > 220) return;
      if (/^(son dakika|tümünü gör|sözcü tv|canlı izle)$/i.test(title)) return;

      var container = link.closest(".news-card, .breaking-news, article, section, li") || link.parentElement;
      var detail = searchItemDetail(container, title);
      if (detail.length > 180) detail = "";

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 4) return null;

    var result = listContentResult({
      title: (metadata && metadata.title) || document.title || "Sözcü",
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || "Sözcü",
      items: items
    });
    result.hostAware = true;
    result.statusPage = true;
    return result;
  }

  var sozcuBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return sozcuContent(metadata) || sozcuBaseHostAwareContent(metadata, pageText);
  };
