  var multiTopicConvertedViews = new WeakMap();

  function multiTopicIgnoredContainerSelector() {
    return [
      "aside", "nav", "footer", "[role='complementary']", "[role='navigation']",
      "[aria-label*='related' i]", "[aria-label*='recommended' i]", "[aria-label*='latest' i]",
      "[class*='related' i]", "[class*='recommend' i]", "[class*='recirculat' i]",
      "[class*='liveblog' i]", "[class*='live-blog' i]",
      "[class*='sidebar' i]", "[class*='side-bar' i]", "[class*='widget' i]",
      "[class*='comment' i]", "[class*='discussion' i]", "[class*='community' i]",
      "[class*='popular' i]", "[class*='trending' i]", "[class*='suggest' i]",
      "[class*='teaser' i]", "[class*='also-read' i]", "[class*='read-more' i]",
      "[class*='more-news' i]", "[class*='more-stories' i]", "[class*='more-from' i]", "[class*='front-page' i]",
      "[class*='article-list' i]", "[class*='content-list' i]", "[class*='story-list' i]",
      "[class*='news-list' i]", "[class*='headline-list' i]", "[class*='feed' i]",
      "[class*='story-card' i]", "[class*='storycard' i]", "[class*='article-related-content' i]",
      "[id*='related' i]", "[id*='recommend' i]", "[id*='comment' i]", "[id*='sidebar' i]", "[id*='widget' i]",
      "[data-component*='article-list' i]", "[data-component*='related' i]",
      "[data-testid*='related' i]", "[data-testid*='recommend' i]", "[data-testid*='comment' i]"
    ].join(", ");
  }

  function multiTopicViewMarkdown(content, html, fallback) {
    if (typeof markdownFor !== "function") return fallback || "";
    var cacheable = content && (typeof content === "object" || typeof content === "function");
    var cached = cacheable && multiTopicConvertedViews.get(content);
    var url = location.href;
    var base = document.baseURI;
    if (cached && cached.html === html && cached.url === url && cached.base === base &&
        cached.converter === markdownFor) return cached.markdown;

    var markdown = markdownFor(html) || "";
    if (cacheable) {
      multiTopicConvertedViews.set(content, {
        html: html, url: url, base: base, converter: markdownFor, markdown: markdown
      });
    }
    return markdown;
  }

  function multiTopicExtractionView(content, markdown) {
    var root = document.createElement("div");
    root.innerHTML = content && content.html ? content.html : "";
    if (!root.innerHTML) return { root: null, markdown: markdown };

    var ignoredContainers = root.querySelectorAll(multiTopicIgnoredContainerSelector());
    Array.prototype.forEach.call(ignoredContainers, function(node) {
      node.parentNode.removeChild(node);
    });

    return {
      root: root,
      markdown: multiTopicViewMarkdown(content, root.innerHTML || "", markdown)
    };
  }
