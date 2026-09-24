  function focalPermalinkUrl(href) {
    var value = materializedHttpUrl(href);
    if (!value) return null;
    try {
      var parsed = new URL(value, location.href);
      parsed.hash = "";
      return parsed.href;
    } catch (_error) {
      return null;
    }
  }

  function focalPermalinkArticleContent(metadata) {
    if (!document.body || !articleLikePath() || queryOrCategoryPage()) return null;

    var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(main) {
      return !elementSubtreeHidden(main) && !main.closest("aside, nav, footer, header");
    });
    if (mains.length !== 1) return null;
    var main = mains[0];
    var currentUrl = focalPermalinkUrl(location.href);
    if (!currentUrl) return null;

    var matchingLinks = Array.from(main.querySelectorAll("li h1 a[href], li h2 a[href], li h3 a[href], li h4 a[href]")).filter(function(link) {
      return !elementSubtreeHidden(link) && focalPermalinkUrl(link.getAttribute("href")) === currentUrl &&
        !link.closest("nav, header, footer, aside, form");
    });
    if (matchingLinks.length !== 1) return null;

    var heading = matchingLinks[0].closest("h1, h2, h3, h4");
    var record = heading && heading.closest("li");
    var list = record && record.parentElement;
    if (!record || !list || !list.matches("ul, ol") || record.querySelector("li, article") ||
        Array.from(list.children).filter(function(node) {
          return node.matches("li") && !elementSubtreeHidden(node);
        }).length !== 1) return null;

    var visible = visibilityPrunedClone(record, document);
    var paragraphs = Array.from(visible.querySelectorAll("p")).filter(function(node) {
      return normalizeText(node.textContent || "").length >= 40;
    });
    if (paragraphs.length < 3 || normalizeText(visible.textContent || "").length < 280) return null;

    var neighbors = Array.from(main.querySelectorAll("li")).filter(function(node) {
      return !record.contains(node) && !elementSubtreeHidden(node) && !node.closest("nav, header, footer, aside, form") &&
        !!node.querySelector("h2, h3, h4") && !!node.querySelector("p");
    });
    if (!neighbors.length) return null;
    var otherMaterial = main.querySelectorAll("p, blockquote, pre, figure, img, video, audio, article, [role='comment'], [itemprop~='comment']");
    if (Array.prototype.some.call(otherMaterial, function(node) {
      return !elementSubtreeHidden(node) && !record.contains(node) &&
        !neighbors.some(function(peer) { return peer.contains(node); });
    })) return null;
    var otherHeadings = main.querySelectorAll("h1, h2, h3, h4");
    if (Array.prototype.some.call(otherHeadings, function(node) {
      return !elementSubtreeHidden(node) && !record.contains(node) &&
        !neighbors.some(function(peer) { return peer.contains(node); });
    })) return null;

    var clone = cleanClone(visible);
    var article = document.createElement("article");
    while (clone.firstChild) article.appendChild(clone.firstChild);
    cleanupGenericArticleRoot(article);
    var selectedHeading = article.querySelector("h1, h2, h3, h4");
    var title = normalizeText(heading.textContent || "");
    if (!selectedHeading || normalizeText(selectedHeading.textContent || "") !== title) return null;
    var titleNode = document.createElement("h1");
    titleNode.textContent = title;
    selectedHeading.replaceWith(titleNode);
    var text = normalizeText(article.textContent || "");
    if (!paragraphs.every(function(node) { return text.indexOf(normalizeText(node.textContent || "")) !== -1; })) return null;

    var publishedTime = (metadata && metadata.publishedTime) || null;
    var routeDate = location.pathname.match(/\/(20\d{2})\/(\d{2})\/(\d{2})(?:\/|$)/);
    if (routeDate) {
      var day = routeDate[1] + "-" + routeDate[2] + "-" + routeDate[3];
      if (!isNaN(Date.parse(day)) && (!publishedTime || publishedTime.slice(0, 10) !== day)) publishedTime = day;
    }

    return {
      title: title,
      excerpt: readabilityExcerptPrefix(paragraphs[0].textContent || "") || normalizeText(paragraphs[0].textContent || ""),
      byline: null,
      publishedTime: publishedTime,
      html: article.outerHTML,
      textContent: text,
      readerMode: false,
      contentType: "article",
      focalPermalinkContent: true
    };
  }
