  function yleLiveArticleContent(metadata) {
    if (!yleLiveItemPage()) return null;

    var item = yleLiveSelectedItem();
    if (!item) return null;

    yleLiveRemovePageLiveBlogData();

    return profileArticleContent(metadata, item, {
      title: yleLiveItemTitle(item) || metadata.title,
      byline: yleLiveItemByline(item) || metadata.byline,
      publishedTime: yleLiveItemPublishedTime(item) || metadata.publishedTime,
      minTextLength: 180,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".post-header",
          "button",
          "iframe",
          "video",
          "[data-testid='video-player']",
          "[class*='player' i]",
          "[class*='Preview' i]",
          "[class*='Restrictions' i]",
          "[class*='share' i]"
        ].join(", "));

        root.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
          script.remove();
        });
      }
    });
  }

  function yleLiveItemPage() {
    if (!hostMatches(/(^|\.)yle\.fi$/)) return false;
    return /^\/a\/\d+(?:-\d+)+\/\d+(?:-\d+)+\/?$/i.test(location.pathname || "");
  }

  function yleLiveSelectedItem() {
    var items = Array.prototype.slice.call(document.querySelectorAll("article.post-container"));
    if (!items.length) return null;

    return items.find(function(item) {
      return !!item.querySelector(".post-content h2, .post-content h3, script[type='application/ld+json']");
    }) || items[0];
  }

  function yleLiveItemTitle(item) {
    return yleLiveFirstText(item, [".post-content h2", ".post-content h3", "h2", "h3"]);
  }

  function yleLiveFirstText(root, selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = root.querySelector(selectors[i]);
      var text = normalizeText(node && node.textContent);
      if (text) return text;
    }
    return "";
  }

  function yleLiveItemByline(item) {
    var header = item.querySelector(".post-header");
    if (!header) return "";

    var candidates = Array.prototype.slice.call(header.querySelectorAll("span[aria-label], span[title]"));
    var names = candidates.map(function(node) {
      return normalizeText(node.getAttribute("aria-label") || node.getAttribute("title") || node.textContent || "");
    }).filter(Boolean);

    return names[0] || "";
  }

  function yleLiveItemPublishedTime(item) {
    var time = item.querySelector("time[datetime]");
    return time ? time.getAttribute("datetime") : null;
  }

  function yleLiveRemovePageLiveBlogData() {
    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      var text = script.textContent || "";
      if (/LiveBlogPosting|liveBlogUpdate/i.test(text)) script.remove();
    });
  }

  var yleLiveBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return yleLiveArticleContent(metadata) || yleLiveBaseHostAwareContent(metadata, pageText);
  };
