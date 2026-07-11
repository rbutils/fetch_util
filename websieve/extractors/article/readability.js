  function readabilityContent() {
    if (typeof Readability !== "function") return null;

    try {
      var comments = commentMarkup(document);
      var clone = safeReadableDocumentClone();
      if (commentOnlyRoot(clone)) return null;
      prepareInlineArticleProse(clone);
      cleanupCookieChrome(clone);
      var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output, .mw-parser-output");
      if (!mediaWikiLike) cleanupAgentRoot(clone);
      cleanupGenericArticleRoot(clone);
      var article = new Readability(clone).parse();
      if (!article || !article.content) return null;
      if (normalizeText(article.textContent || "").length < 40) return null;
      article.content += comments;

      return {
        title: article.title || document.title,
        byline: article.byline || null,
        excerpt: article.excerpt || null,
        siteName: article.siteName || location.hostname,
        publishedTime: article.publishedTime || null,
        html: article.content,
        textContent: article.textContent || "",
        readerMode: true,
        contentType: "article"
      };
    } catch (_error) {
      // Fall through to the shared article/list heuristics instead of aborting.
      return null;
    }
  }

  function focalArticleRoot(root) {
    var heading = root.querySelector("h1, h2, [itemprop='headline']");
    var title = normalizeText((heading && heading.textContent) || "");
    var body = Array.prototype.filter.call(root.querySelectorAll("p, [itemprop='articleBody']"), function(node) {
      return !node.closest("#comments, .comments, .comment-list, [class*='comment' i], [id*='comment' i]");
    }).map(function(node) { return normalizeText(node.textContent); }).join(" ");
    return !!title && body.length >= 40;
  }

  function commentOnlyRoot(root) {
    var comments = root.querySelectorAll("#comments, .comments, .comments-area, .comment-list, .comments-section, #disqus_thread, [class*='comment' i]");
    if (!comments.length) return false;
    var total = normalizeText(root.textContent || "").length;
    var commentText = Array.prototype.reduce.call(comments, function(length, node) {
      return Math.max(length, normalizeText(node.textContent || "").length);
    }, 0);
    return commentText > 0 && commentText >= total * 0.7;
  }

  function commentMarkup(root) {
    var containers = [];
    root.querySelectorAll("#comments, .comments, .comments-area, .comment-list, .comments-section, #disqus_thread, [class*='comment' i]").forEach(function(node) {
      if (!node.querySelector("p, li, [class*='body' i]") || normalizeText(node.textContent || "").length < 40) return;
      if (!containers.some(function(parent) { return parent.contains(node); })) containers.push(node);
    });
    return containers.map(function(node) { return node.outerHTML; }).join("");
  }

  function prepareInlineArticleProse(root) {
    root.querySelectorAll("p span, li span, blockquote span, p font, li font, blockquote font").forEach(function(node) {
      if (node.querySelector("p, li, blockquote, div, ul, ol, table, pre")) return;
      node.replaceWith.apply(node, Array.prototype.slice.call(node.childNodes));
    });
  }
