  function pikabuContent(metadata) {
    if (!hostMatches(/(^|\.)pikabu\.ru$/)) return null;
    if (!/^\/story\//i.test(location.pathname || "")) return null;

    var story = pikabuStoryRoot();
    if (!story) return null;

    var body = pikabuStoryBody(story, metadata);
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".story__title", "h1.title", "h1"]) || metadata.title,
      byline: firstText([".story__user-link", ".user__nick", "[data-story-username]"]) || metadata.byline,
      minTextLength: 60,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".comments",
          "#comments",
          "[id^='comment_']",
          ".story__footer",
          ".story__tools",
          ".story__left",
          ".story__save",
          ".story__share",
          ".story__comments-link",
          ".story-title-icons",
          "[data-role='player-controls']",
          "[class*='player-controls']",
          "[class*='timeline']",
          "[class*='player-btn']",
          "[class*='recommend']",
          "[class*='advert']",
          "[data-adfox]",
          "svg"
        ].join(", "));

        root.querySelectorAll("p, div, span, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(00:\d{2}\s*\/\s*\d{2}:\d{2}|раскрыть \d+ комментар|ещё \d+|поделиться|сохранить)$/i.test(text)) el.remove();
        });

        var seenLinks = {};
        root.querySelectorAll("a[href]").forEach(function(link) {
          var href = link.getAttribute("href") || "";
          if (seenLinks[href]) link.remove();
          seenLinks[href] = true;
        });
      },
      validateMarkdown: function(markdown) {
        return !/\b\d+\s+час(?:а|ов)?\s+назад[\s\S]{0,240}\bраскрыть\s+ветку/i.test(markdown);
      },
      extra: { docsLike: true }
    });
  }

  function pikabuStoryRoot() {
    var candidates = Array.prototype.slice.call(document.querySelectorAll(
      ".page-story[data-story-id], .story[data-story-id], [data-story-id]"
    ));

    for (var i = 0; i < candidates.length; i++) {
      var node = candidates[i];
      if (node.closest(".comments, #comments, [id^='comment_']")) continue;
      if (node.querySelector(".story__title") && node.querySelector(".story__content, #content-story-text, .story-body, div.story__text")) return node;
    }

    return null;
  }

  function pikabuStoryBody(story, metadata) {
    var content = story.querySelector(".story__content") ||
      story.querySelector("#content-story-text") ||
      story.querySelector(".story-body") ||
      story.querySelector("div.story__text");
    if (!content) return null;

    var root = document.createElement("div");
    root.setAttribute("data-fetchutil-profile", "pikabu");

    var title = firstText([".story__title", "h1.title", "h1"]) || (metadata && metadata.title);
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    var metaText = normalizeText([
      firstText([".story__user-link", ".user__nick"]),
      firstText([".story__datetime-link", ".story__datetime"])
    ].filter(Boolean).join(" - "));
    if (metaText) {
      var meta = document.createElement("p");
      meta.textContent = metaText;
      root.appendChild(meta);
    }

    pikabuAppendMediaSummary(root, story, title);
    root.appendChild(safeDeepClone(content, document));

    var tags = story.querySelector(".story__tags");
    if (tags) root.appendChild(safeDeepClone(tags, document));

    return root;
  }

  function pikabuAppendMediaSummary(root, story, title) {
    var mediaRoot = story.querySelector(".story__content");
    if (!mediaRoot) return;

    var posterNode = mediaRoot.querySelector("[poster]");
    var poster = posterNode && posterNode.getAttribute("poster");
    if (poster) {
      var image = document.createElement("img");
      image.setAttribute("src", poster);
      if (title) image.setAttribute("alt", title);
      root.appendChild(image);
    }

    var videoLink = mediaRoot.querySelector("a[href*='/video/story/']");
    if (videoLink && videoLink.getAttribute("href")) {
      var paragraph = document.createElement("p");
      var link = document.createElement("a");
      link.setAttribute("href", absoluteUrl(videoLink.getAttribute("href")));
      link.textContent = normalizeText(videoLink.textContent || "Перейти к видео") || "Перейти к видео";
      paragraph.appendChild(link);
      root.appendChild(paragraph);
    }
  }

  registerHostAwareProfile(true, pikabuContent);