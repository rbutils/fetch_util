  function yleLiveArticleContent(metadata) {
    if (!yleLiveItemPage()) return null;

    return liveblogSingleEntryContent(metadata, {
      entrySelector: "article.post-container",
      entryMatcher: yleLiveItemMatcher,
      bodySelector: ".post-content",
      titleSelector: [".post-content h2", ".post-content h3", "h2", "h3"],
      byline: function(md, root, item) { return yleLiveItemByline(item) || md.byline; },
      publishedTime: function(md, root, item) { return yleLiveItemPublishedTime(item) || md.publishedTime; },
      beforeBuild: yleLiveRemovePageLiveBlogData,
      minTextLength: 180,
      cleanupSelectors: [
        ".post-header",
        "button",
        "iframe",
        "video",
        "[data-testid='video-player']",
        "[class*='player' i]",
        "[class*='Preview' i]",
        "[class*='Restrictions' i]",
        "[class*='share' i]"
      ],
      rewriteRoot: function(root) {
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

  function yleLiveItemMatcher(item) {
    return !!item.querySelector(".post-content h2, .post-content h3, script[type='application/ld+json']");
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

  registerHostAwareProfile(true, yleLiveArticleContent);