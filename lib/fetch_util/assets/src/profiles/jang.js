  function jangArticleContent(metadata) {
    if (!hostMatches(/(^|\.)jang\.com\.pk$/)) return null;

    return jangLiveblogStoryContent(metadata) || jangDetailArticleContent(metadata);
  }

  function jangDetailArticleContent(metadata) {
    var article = document.querySelector(".story-content, .news-detail, .article-body, div.nn-article-body, .detail_view_content");
    if (!article) return null;

    return profileArticleContent(metadata, article, {
      title: firstText([".detail-right-top h1", ".main-heading h1", ".news-title", ".title", "h1"]) || metadata.title,
      byline: firstText([".by_author h5", ".author", "[rel='author']"]) || metadata.byline,
      minTextLength: 180,
      rewriteRoot: jangCleanArticleRoot
    });
  }

  function jangLiveblogStoryContent(metadata) {
    if (!/^\/liveblog\//i.test(location.pathname || "")) return null;

    var story = jangLiveblogSelectedStory();
    if (!story) return null;

    return profileArticleContent(metadata, story, {
      title: firstTextIn(story, ["h2"]) || firstText([".time_first_story h1", "h1"]) || metadata.title,
      byline: firstTextIn(story, [".by_author h5"]) || metadata.byline,
      minTextLength: 120,
      rewriteRoot: jangCleanArticleRoot,
      extra: { isolatedJangLiveblogStory: true }
    });
  }

  function jangLiveblogSelectedStory() {
    var storyParam = new URLSearchParams(location.search || "").get("story");
    if (storyParam) {
      var byParam = document.getElementById("story" + storyParam);
      if (byParam) return byParam;
    }

    var canonical = document.querySelector("link[rel='canonical']");
    var canonicalUrl = canonical && canonical.getAttribute("href");
    if (canonicalUrl) {
      var match = canonicalUrl.match(/[?&]story=(\d+)/i);
      if (match) {
        var byCanonical = document.getElementById("story" + match[1]);
        if (byCanonical) return byCanonical;
      }
    }

    return document.querySelector("#liveBlogStorySection .listpost > li[id^='story']");
  }

  function jangCleanArticleRoot(root) {
    removeAll(root, [
      ".share_icon",
      ".full_social",
      ".share-this-icons",
      ".share-button-list",
      ".detail_right_sky",
      ".content-area-ads",
      ".adsslotDiv",
      "[id^='div-gpt-ad']",
      "script",
      "style"
    ].join(", "));

    root.querySelectorAll("a").forEach(function(link) {
      var text = normalizeText(link.textContent || "");
      if (/^مزید پڑھیے:?$/i.test(text)) link.remove();
    });
  }

  function firstTextIn(root, selectors) {
    for (var i = 0; i < selectors.length; i++) {
      var node = root.querySelector(selectors[i]);
      var text = normalizeText(node && node.textContent);
      if (text) return text;
    }
    return "";
  }

  var jangBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return jangArticleContent(metadata) || jangBaseHostAwareContent(metadata, pageText);
  };

  var jangBaseDetectContentFormat = detectContentFormat;
  detectContentFormat = function(metadata, content, markdown) {
    if (hostMatches(/(^|\.)jang\.com\.pk$/) && content && content.isolatedJangLiveblogStory) return null;
    return jangBaseDetectContentFormat(metadata, content, markdown);
  };
